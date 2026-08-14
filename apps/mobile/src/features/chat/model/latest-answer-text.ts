import type { UIMessage } from 'ai';

/** The latest assistant reply of the transcript, as plain (marked-up) text. */
export function latestAnswerText(messages: UIMessage[]): string {
  const assistant = [...messages].reverse().find((message) => message.role === 'assistant');
  if (!assistant) return '';
  return assistant.parts
    .flatMap((part) => (part.type === 'text' ? [part.text] : []))
    .join('');
}
