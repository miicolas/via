"use client";

import { useEffect, useState, type ReactNode } from "react";

import { LaunchAction } from "@/components/ui/launch-action";
import { SplitActionLink } from "@/components/ui/split-action-link";

const STORAGE_KEY = "via.pendingMeetupInvitationURL";

export function MeetupInvitationActions({ token }: { readonly token: string }): ReactNode {
  const [deepLink, setDeepLink] = useState(`via://meet/${token}`);

  useEffect(() => {
    // The group key lives after `#`, so this is deliberately browser-only: the
    // page server and its logs never receive it. Keeping the complete link
    // locally lets the traveller come back after installing Via.
    const completeURL = window.location.href;
    try {
      window.localStorage.setItem(STORAGE_KEY, completeURL);
    } catch {
      // Private browsing may deny storage; the current URL still works.
    }
    setDeepLink(`via://meet/${token}${window.location.hash}`);
  }, [token]);

  return (
    <div className="mt-8 flex flex-wrap items-center gap-4">
      <SplitActionLink label="Ouvrir dans Via" href={deepLink} tone="dark" />
      <LaunchAction mode="badge" appearance="black" />
      <p className="w-full max-w-xl text-sm leading-6 text-white/75">
        Après une installation, revenez sur cette page puis touchez « Ouvrir dans Via ».
        iOS ne garantit pas la reprise automatique d’un lien après l’App Store.
      </p>
    </div>
  );
}
