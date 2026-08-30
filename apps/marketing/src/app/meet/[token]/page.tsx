import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import type { ReactNode } from "react";

import { canonicalInvitationToken } from "@/lib/invitation/canonical-invitation-token";
import { fetchMeetupInvitation } from "@/lib/meetup-invitation";
import { InvitationHero } from "../invitation-hero";
import { InvitationUnavailable } from "../invitation-unavailable";
import { MeetupInvitationActions } from "./meetup-invitation-actions";

type Props = { readonly params: Promise<{ token: string }> };

export const metadata: Metadata = {
  title: "Invitation à un rendez-vous",
  description: "Rejoignez un rendez-vous dans Via.",
  robots: { index: false, follow: false },
};

/** Module scope: the formatter is identical for every request. */
const arrivalFormat = new Intl.DateTimeFormat("fr-FR", {
  dateStyle: "full",
  timeStyle: "short",
  timeZone: "Europe/Paris",
});

const STATUS_LABELS = {
  available: "Invitation disponible",
  full: "Le groupe est complet",
  expired: "Cette invitation a expiré",
  revoked: "Cette invitation a été révoquée",
} as const;

export default async function MeetupInvitationPage({ params }: Props): Promise<ReactNode> {
  const { token: rawToken } = await params;
  const token = canonicalInvitationToken(rawToken);
  if (!token) notFound();
  if (token !== rawToken) redirect(`/meet/${token}`);

  const result = await fetchMeetupInvitation(token);
  if (result.kind === "notFound") return notFound();
  if (result.kind !== "ready") return <InvitationUnavailable eyebrow="Rendez-vous" />;

  const { invitation } = result;
  return (
    <InvitationHero
      eyebrow={`Rendez-vous proposé par ${invitation.organizerDisplayName}`}
      title={`Retrouvez-vous à ${invitation.destination.name}`}
      detail={`Arrivée prévue ${arrivalFormat.format(new Date(invitation.targetArrivalAt))}`}
      status={STATUS_LABELS[invitation.status]}
    >
      {invitation.status === "available" ? <MeetupInvitationActions token={token} /> : null}
    </InvitationHero>
  );
}
