import * as z from 'zod';

import {
  nativeChatDestinationSchema,
  nativeChatEventSchema,
  nativeChatMessageSchema,
  nativeChatRequestSchema,
} from './schema';

export type NativeChatMessage = z.infer<typeof nativeChatMessageSchema>;
export type NativeChatRequest = z.infer<typeof nativeChatRequestSchema>;
export type NativeChatDestination = z.infer<typeof nativeChatDestinationSchema>;
export type NativeChatEvent = z.infer<typeof nativeChatEventSchema>;
