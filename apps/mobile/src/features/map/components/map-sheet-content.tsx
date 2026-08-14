import { ChatScreen } from '@/features/chat/components/chat-screen';
import { JourneySheetScreen } from '@/features/journey/components/sheet-screen';

type MapSheetContentProps = {
  chatOpen: boolean;
  toolbarHeight: number;
};

export function MapSheetContent({ chatOpen, toolbarHeight }: MapSheetContentProps) {
  return chatOpen ? (
    <ChatScreen toolbarHeight={toolbarHeight} />
  ) : (
    <JourneySheetScreen toolbarHeight={toolbarHeight} />
  );
}
