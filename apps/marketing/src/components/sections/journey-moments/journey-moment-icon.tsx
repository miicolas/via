import type { JourneyMomentIcon as JourneyMomentIconName } from "@/constants/types";
import { MapPinned, Navigation2, Search, TriangleAlert } from "lucide-react";
import type { ReactNode } from "react";

export function JourneyMomentIcon({
  name,
}: {
  readonly name: JourneyMomentIconName;
}): ReactNode {
  const className = "size-5 sm:size-6";

  switch (name) {
    case "search":
      return <Search aria-hidden="true" className={className} />;
    case "journey":
      return <Navigation2 aria-hidden="true" className={className} />;
    case "disruption":
      return <TriangleAlert aria-hidden="true" className={className} />;
    case "station":
      return <MapPinned aria-hidden="true" className={className} />;
  }
}
