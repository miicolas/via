"use client";

import { launch, type LaunchConfiguration } from "@/constants/launch";
import { AppStoreBadgeLink } from "@/components/ui/app-store-badge-link";
import { SplitActionLink } from "@/components/ui/split-action-link";
import type { ReactNode } from "react";

type LaunchActionProps = {
  readonly configuration?: LaunchConfiguration;
  readonly mode: "badge" | "button";
  readonly appearance?: "black" | "white";
  readonly tone?: "theme" | "dark";
};

/** Render the one launch policy without ever manufacturing an inert control. */
export function LaunchAction({
  configuration = launch,
  mode,
  appearance = "black",
  tone = "theme",
}: LaunchActionProps): ReactNode {
  if (configuration.phase === "prelaunch") {
    return (
      <span
        className={`inline-flex min-h-11 items-center justify-center text-sm font-semibold ${mode === "badge" ? "min-w-44 rounded-lg border border-current/20 px-4" : "rounded-xl px-6 py-3"}`}
      >
        {configuration.availabilityLabel}
      </span>
    );
  }

  if (mode === "badge") {
    return <AppStoreBadgeLink {...configuration.appStoreAction} appearance={appearance} />;
  }
  return <SplitActionLink {...configuration.appStoreAction} tone={tone} />;
}
