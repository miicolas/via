import type { Journey } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { GlassSurface } from '@/components/glass-surface';
import { JourneyDepartureNote } from '@/features/journey/components/departure-note';
import { JourneyDisruptionNote } from '@/features/journey/components/disruption-note';
import { JourneyDurationHero } from '@/features/journey/components/duration-hero';
import { JourneyGoButton } from '@/features/journey/components/go-button';
import { JourneyLegStrip } from '@/features/journey/components/leg-strip';
import { journeyMinutes } from '@/features/journey/model/minutes';
import { visibleJourneyWarning } from '@/features/journey/model/visible-warning';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyCardProps = {
  journey: Journey;
  onPress: () => void;
  /** Why this one is on top. Absent unless the data actually supports the claim. */
  reason?: string;
};

/** The recommended journey, given the room to be read before the alternatives. */
export function JourneyCard({ journey, onPress, reason }: JourneyCardProps) {
  const { colors } = useAppTheme();
  const transit = journey.sections.filter((section) => section.type === 'transit');
  const firstTransit = transit[0];
  const lastTransit = transit.at(-1);
  const duration = journeyMinutes(journey.durationSeconds);
  const warning = visibleJourneyWarning(journey);

  return (
    <GlassSurface variant="card">
      <View style={styles.summary}>
        <JourneyLegStrip journey={journey} />
        <JourneyDurationHero minutes={duration} />
      </View>

      <View style={styles.heading}>
        <Text numberOfLines={1} selectable style={[styles.route, { color: colors.ink }]}>
          {routeTitle(firstTransit?.from.name, lastTransit?.to.name)}
        </Text>
        {reason ? <Text style={[styles.reason, { color: colors.muted }]}>{reason}</Text> : null}
      </View>

      {warning ? <JourneyDisruptionNote route={firstTransit?.route} text={warning} /> : null}

      <View style={[styles.footer, { borderTopColor: colors.hairline }]}>
        <JourneyDepartureNote
          arrivalAt={journey.arrivalAt}
          departureAt={journey.departureAt}
          platform={firstTransit?.platform}
        />
        <JourneyGoButton
          accessibilityLabel={`Choisir l’itinéraire de ${duration} minutes`}
          onPress={onPress}
        />
      </View>
    </GlassSurface>
  );
}

function routeTitle(from?: string, to?: string) {
  if (from && to) return `${from} → ${to}`;
  return 'Itinéraire à pied';
}

const styles = StyleSheet.create({
  summary: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  heading: { gap: 3 },
  route: {
    fontFamily: 'Archivo_700Bold',
    fontSize: 17,
    lineHeight: 22,
    letterSpacing: -0.34,
  },
  reason: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    lineHeight: 17,
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
    paddingTop: 14,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
});
