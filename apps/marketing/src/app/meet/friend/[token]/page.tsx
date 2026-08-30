import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import type { ReactNode } from "react";

import { canonicalInvitationToken } from "@/lib/invitation/canonical-invitation-token";
import { fetchFriendInvitation } from "@/lib/friend-invitation";
import { InvitationHero } from "../../invitation-hero";
import { InvitationUnavailable } from "../../invitation-unavailable";
import { FriendInvitationActions } from "./friend-invitation-actions";

type Props = { readonly params: Promise<{ token: string }> };

export const metadata: Metadata = {
  title: "Invitation d’ami Via",
  description: "Ajoutez un ami dans Via avec son lien privé.",
  robots: { index: false, follow: false },
};

const STATUS_LABELS = {
  available: "Invitation disponible",
  expired: "Cette invitation a expiré",
  revoked: "Cette invitation a été révoquée",
} as const;

export default async function FriendInvitationPage({ params }: Props): Promise<ReactNode> {
  const { token: rawToken } = await params;
  const token = canonicalInvitationToken(rawToken);
  if (!token) notFound();
  if (token !== rawToken) redirect(`/meet/friend/${token}`);

  const result = await fetchFriendInvitation(token);
  if (result.kind === "notFound") return notFound();
  if (result.kind !== "ready") return <InvitationUnavailable eyebrow="Amis" />;

  const { invitation } = result;
  return (
    <InvitationHero
      eyebrow="Invitation privée"
      title={`${invitation.inviterDisplayName} vous invite sur Via`}
      detail="Seuls votre nom et vos initiales seront partagés."
      status={STATUS_LABELS[invitation.status]}
    >
      {invitation.status === "available" ? <FriendInvitationActions token={token} /> : null}
    </InvitationHero>
  );
}
