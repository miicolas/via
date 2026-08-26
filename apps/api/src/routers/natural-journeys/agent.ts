import type { JourneysResponse, NaturalJourneyInterpretation } from '@via/contract';

import type { HandleRegistry } from './handles';
import type {
  OpenAiResponsesTransport,
  ReasoningEffort,
  ResponsesInputItem,
  ResponsesUsage,
} from './openai-transport';
import { FINAL_OUTPUT_FORMAT, SYSTEM_PROMPT, parseFinalOutput } from './prompt';
import { MAX_PLANS, MAX_SEARCHES, type ToolCounters, type Toolset } from './tools';

const DEFAULT_UNSUPPORTED = "Je n'ai pas compris cette demande d'itinéraire.";
/** Two lookups, one calculation, plus a little slack to read the tool errors and finalize. */
const DEFAULT_MAX_TURNS = MAX_SEARCHES + MAX_PLANS + 2;
/** Reasoning tokens included — generous for orchestration, fatal for a runaway. */
const MAX_OUTPUT_TOKENS = 2_000;

export type AgentResult =
  | { kind: 'ready'; interpretation: NaturalJourneyInterpretation; journeys: JourneysResponse }
  | { kind: 'unsupported'; message: string; examples: string[] }
  | {
      kind: 'error';
      category: 'timeout' | 'invalid-output' | 'tool-budget-exceeded' | 'openai-error';
    };

export type AgentRun = {
  result: AgentResult;
  usage: ResponsesUsage | null;
  toolCalls: ToolCounters;
};

export type AgentParams = {
  transport: OpenAiResponsesTransport;
  toolset: Toolset;
  registry: HandleRegistry;
  model: string;
  safetyIdentifier: string;
  /** The phrase and its temporal/location context, assembled by the service. */
  userMessage: string;
  timeoutMs: number;
  /** External cancellation (client disconnect). Distinct from the timeout. */
  signal: AbortSignal;
  /** How long the model may think per turn; this loop is orchestration, not prose. */
  reasoningEffort?: ReasoningEffort;
  maxTurns?: number;
  /** Injectable clock so the deadline is testable without wall-time. */
  clock?: () => number;
};

/**
 * The stateless tool loop. It resends the whole transcript every turn
 * (`store: false`, no `previous_response_id`), runs each tool through the
 * budgeted toolset, and finishes on the model's structured message. A `ready`
 * decision is only trusted through a plan handle the server itself minted — the
 * model's own words never become the answer.
 */
export async function runNaturalJourneyAgent({
  transport,
  toolset,
  registry,
  model,
  safetyIdentifier,
  userMessage,
  timeoutMs,
  signal,
  reasoningEffort = 'none',
  maxTurns = DEFAULT_MAX_TURNS,
  clock = () => Date.now(),
}: AgentParams): Promise<AgentRun> {
  const deadline = clock() + timeoutMs;
  const input: ResponsesInputItem[] = [
    { role: 'system', content: SYSTEM_PROMPT },
    { role: 'user', content: userMessage },
  ];
  let usage: ResponsesUsage | null = null;

  const finish = (result: AgentResult): AgentRun => ({
    result,
    usage,
    toolCalls: { ...toolset.counters },
  });

  for (let turn = 0; turn < maxTurns; turn += 1) {
    if (signal.aborted) throw cancellation(signal);
    const remaining = deadline - clock();
    if (remaining <= 0) return finish({ kind: 'error', category: 'timeout' });

    const turnSignal = AbortSignal.any([signal, AbortSignal.timeout(remaining)]);
    let turnResult;
    try {
      turnResult = await transport.create(
        {
          model,
          input,
          tools: toolset.definitions,
          text: { verbosity: 'low', format: FINAL_OUTPUT_FORMAT },
          reasoning: { effort: reasoningEffort },
          store: false,
          safety_identifier: safetyIdentifier,
          // Reasoning tokens count against this cap; it guards against a
          // runaway thinking turn, not against the (small) structured output.
          max_output_tokens: MAX_OUTPUT_TOKENS,
        },
        turnSignal
      );
    } catch (error) {
      if (signal.aborted) throw cancellation(signal);
      if (turnSignal.aborted) return finish({ kind: 'error', category: 'timeout' });
      console.error('[natural-journeys] échec OpenAI', errorSummary(error));
      return finish({ kind: 'error', category: 'openai-error' });
    }
    usage = accumulateUsage(usage, turnResult.usage);

    if (turnResult.functionCalls.length === 0) {
      const final = parseFinalOutput(turnResult.outputText);
      if (!final) return finish({ kind: 'error', category: 'invalid-output' });
      if (final.outcome === 'unsupported') {
        return finish({
          kind: 'unsupported',
          message: final.unsupportedMessage.trim() || DEFAULT_UNSUPPORTED,
          examples: final.examples,
        });
      }
      const plan = registry.resolvePlan(final.planHandle);
      // A "ready" verdict pointing at a plan the server never minted is not a
      // real plan — treat it as an invalid answer, not a silent success.
      if (!plan) return finish({ kind: 'error', category: 'invalid-output' });
      return finish({
        kind: 'ready',
        interpretation: plan.interpretation,
        journeys: plan.journeys,
      });
    }

    // Echo the assistant's tool calls back into the transcript, then answer
    // them all at once: two place searches must not queue behind each other.
    for (const call of turnResult.functionCalls) {
      input.push({
        type: 'function_call',
        call_id: call.callId,
        name: call.name,
        arguments: call.arguments,
      });
    }
    const outputs = await Promise.all(
      turnResult.functionCalls.map((call) => toolset.runTool(call.name, call.arguments))
    );
    turnResult.functionCalls.forEach((call, index) => {
      input.push({ type: 'function_call_output', call_id: call.callId, output: outputs[index] });
    });

    // A minted plan with journeys is the answer: the model's closing message
    // would only repeat the handle, so don't pay another round trip for it.
    const plan = toolset.completedPlan();
    if (plan) {
      return finish({
        kind: 'ready',
        interpretation: plan.interpretation,
        journeys: plan.journeys,
      });
    }
  }

  return finish({
    kind: 'error',
    category: toolset.guardrailTriggered() ? 'tool-budget-exceeded' : 'openai-error',
  });
}

function accumulateUsage(
  total: ResponsesUsage | null,
  turn: ResponsesUsage | null
): ResponsesUsage | null {
  if (!turn) return total;
  if (!total) return turn;
  return {
    input: total.input + turn.input,
    output: total.output + turn.output,
    total: total.total + turn.total,
  };
}

function cancellation(signal: AbortSignal): unknown {
  return signal.reason ?? new DOMException('The operation was aborted.', 'AbortError');
}

function errorSummary(error: unknown): string {
  if (error instanceof Error) return `${error.name}: ${error.message}`;
  return 'unknown error';
}
