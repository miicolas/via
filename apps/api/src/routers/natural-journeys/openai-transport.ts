import OpenAI from 'openai';

/**
 * The normalized Responses-API surface the agent depends on. Keeping it separate
 * from the OpenAI SDK types is the seam: the agent loop and every test speak
 * this shape, so a fake transport needs no network and the SDK can move under us
 * without touching the orchestration.
 */
export type ResponsesToolDefinition = {
  type: 'function';
  name: string;
  description: string;
  parameters: Record<string, unknown>;
  strict: boolean;
};

export type ResponsesTextFormat = {
  type: 'json_schema';
  name: string;
  schema: Record<string, unknown>;
  strict: boolean;
};

/**
 * We run stateless: `store: false` with no `previous_response_id`, so each turn
 * resends the whole transcript. Assistant tool calls ride back as `function_call`
 * items and our answers as `function_call_output` items.
 */
export type ResponsesInputItem =
  | { role: 'system' | 'developer' | 'user'; content: string }
  | { type: 'function_call'; call_id: string; name: string; arguments: string }
  | { type: 'function_call_output'; call_id: string; output: string };

export type ReasoningEffort = 'minimal' | 'low' | 'medium';

export type ResponsesRequest = {
  model: string;
  input: ResponsesInputItem[];
  tools: ResponsesToolDefinition[];
  text: { verbosity: 'low'; format: ResponsesTextFormat };
  reasoning: { effort: ReasoningEffort };
  /** Never persist the phrase or transcript on OpenAI's side. */
  store: false;
  /** HMAC of the identity, never the raw id. */
  safety_identifier: string;
  max_output_tokens?: number;
};

export type ResponsesFunctionCall = { callId: string; name: string; arguments: string };
export type ResponsesUsage = { input: number; output: number; total: number };

export type ResponsesTurn = {
  id: string;
  functionCalls: ResponsesFunctionCall[];
  /** Empty until the model emits its final structured message. */
  outputText: string;
  usage: ResponsesUsage | null;
};

export interface OpenAiResponsesTransport {
  create(request: ResponsesRequest, signal?: AbortSignal): Promise<ResponsesTurn>;
}

/**
 * The production transport. `maxRetries: 0` honours the plan's "no automatic
 * retry" — a failed submission surfaces immediately so the client can decide,
 * rather than silently multiplying cost and latency.
 */
export function createOpenAiResponsesTransport({
  apiKey,
  timeoutMs,
}: {
  apiKey: string;
  timeoutMs: number;
}): OpenAiResponsesTransport {
  const client = new OpenAI({ apiKey, timeout: timeoutMs, maxRetries: 0 });
  return {
    create: async (request, signal) => {
      // The SDK's generics chase the very latest model params; this seam owns
      // the exact request shape, so we hand it across the boundary as-is.
      const response = await client.responses.create(request as never, { signal });
      return normalizeResponse(response as unknown as RawResponse);
    },
  };
}

type RawResponse = {
  id?: string;
  output?: Array<{ type?: string; call_id?: string; name?: string; arguments?: string }>;
  output_text?: string;
  usage?: { input_tokens?: number; output_tokens?: number; total_tokens?: number };
};

function normalizeResponse(response: RawResponse): ResponsesTurn {
  const output = Array.isArray(response.output) ? response.output : [];
  const functionCalls = output
    .filter((item) => item.type === 'function_call')
    .map((item) => ({
      callId: item.call_id ?? '',
      name: item.name ?? '',
      arguments: item.arguments ?? '',
    }));
  const usage = response.usage
    ? {
        input: response.usage.input_tokens ?? 0,
        output: response.usage.output_tokens ?? 0,
        total: response.usage.total_tokens ?? 0,
      }
    : null;
  return {
    id: response.id ?? '',
    functionCalls,
    outputText: response.output_text ?? '',
    usage,
  };
}
