import type { ProcessStepContent } from "./types";

export const processSteps = [
  {
    icon: "calendar-check",
    title: "Schedule kickoff",
    description:
      "Align on scope, structure, and timeline. Whether it's a quick setup or a full migration, we'll take it from there.",
  },
  {
    icon: "users",
    title: "Real-time collaboration",
    description:
      "Work alongside our team with full visibility. Every step follows best practices and thorough QA to ensure quality.",
  },
  {
    icon: "rocket",
    title: "Launch and scale",
    description:
      "Go live with confidence. Our AI continuously learns and improves, helping your team scale effortlessly.",
  },
] as const satisfies readonly ProcessStepContent[];
