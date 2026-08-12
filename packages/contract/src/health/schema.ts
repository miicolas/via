import * as z from 'zod';

export const healthSchema = z.object({
  status: z.literal('ok'),
  db: z.boolean(),
  at: z.iso.datetime(),
});
