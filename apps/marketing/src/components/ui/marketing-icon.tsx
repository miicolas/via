import {
  Activity,
  BarChart3,
  BookOpen,
  Braces,
  Check,
  Clock3,
  Code2,
  Compass,
  Database,
  FileText,
  Globe2,
  Heart,
  KeyRound,
  Layers3,
  LifeBuoy,
  Link2,
  LockKeyhole,
  Map,
  MessageCircle,
  PlugZap,
  Route,
  Search,
  ShieldCheck,
  Sparkles,
  Users,
  Webhook,
  type LucideIcon,
} from "lucide-react";
import type { MarketingIconName } from "@/constants/marketing-pages";
import type { ReactNode } from "react";

const icons: Record<MarketingIconName, LucideIcon> = {
  activity: Activity,
  "book-open": BookOpen,
  braces: Braces,
  chart: BarChart3,
  check: Check,
  clock: Clock3,
  code: Code2,
  compass: Compass,
  database: Database,
  "file-text": FileText,
  globe: Globe2,
  heart: Heart,
  key: KeyRound,
  layers: Layers3,
  "life-buoy": LifeBuoy,
  link: Link2,
  lock: LockKeyhole,
  map: Map,
  message: MessageCircle,
  plug: PlugZap,
  route: Route,
  search: Search,
  shield: ShieldCheck,
  sparkles: Sparkles,
  users: Users,
  webhook: Webhook,
};

export function MarketingIcon({
  name,
  className,
}: {
  readonly name: MarketingIconName;
  readonly className?: string;
}): ReactNode {
  const Icon = icons[name];
  return <Icon className={className} aria-hidden="true" />;
}
