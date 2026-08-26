"use client";

import { makeQueryClient } from "@/lib/query-client";
import { QueryClientProvider } from "@tanstack/react-query";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import type { ReactNode } from "react";
import { useState } from "react";

/**
 * React Query et nuqs n’existent que pour le trajet partagé. Montés à la racine
 * ils rejoignaient le bundle de chaque page — l’accueil, l’aide, le blog —, qui
 * n’ont ni requête client ni état d’URL. Ils vivent donc ici, sur le seul
 * segment qui les lit.
 */
export function JourneyShareProviders({
  children,
}: {
  readonly children: ReactNode;
}): ReactNode {
  const [queryClient] = useState(makeQueryClient);

  return (
    <QueryClientProvider client={queryClient}>
      <NuqsAdapter>{children}</NuqsAdapter>
    </QueryClientProvider>
  );
}
