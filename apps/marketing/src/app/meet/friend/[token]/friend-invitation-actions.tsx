"use client";

import type { ReactNode } from "react";

import { LaunchAction } from "@/components/ui/launch-action";
import { SplitActionLink } from "@/components/ui/split-action-link";

export function FriendInvitationActions({ token }: { readonly token: string }): ReactNode {
  return (
    <div className="mt-8 flex flex-wrap items-center gap-4">
      <SplitActionLink label="Ouvrir dans Via" href={`via://friend/${token}`} tone="dark" />
      <LaunchAction mode="badge" appearance="black" />
      <p className="w-full max-w-xl text-sm leading-6 text-white/75">
        Un compte Sign in with Apple est nécessaire pour devenir amis. Via ne propose
        aucun annuaire et ne lit pas vos contacts.
      </p>
    </div>
  );
}
