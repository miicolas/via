import { useContext } from 'react';

import { ViaChatContext, type ViaChatValue } from '@/features/chat/state/context';

export function useViaChatContext(): ViaChatValue {
  const value = useContext(ViaChatContext);
  if (!value) throw new Error('useViaChatContext requires a ViaChatProvider ancestor.');
  return value;
}
