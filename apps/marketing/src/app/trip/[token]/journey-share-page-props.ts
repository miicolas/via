export type JourneySharePageProps = {
  readonly params: Promise<{ token: string }>;
  readonly searchParams: Promise<Record<string, string | string[] | undefined>>;
};
