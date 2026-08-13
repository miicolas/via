import type { Journey } from '@via/contract';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { SymbolIcon } from '@/components/symbol-icon';
import { JourneyLegStrip } from '@/features/home-map/components/journey-leg-strip';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type JourneyCardProps = {
  journey: Journey;
  onPress: () => void;
};

export function JourneyCard({ journey, onPress }: JourneyCardProps) {
  const { colors } = useHomeMapTheme();
  const transit = journey.sections.filter((section) => section.type === 'transit');
  const firstTransit = transit[0];
  const lastTransit = transit.at(-1);
  const duration = Math.max(1, Math.round(journey.durationSeconds / 60));
  const departure = formatTime(journey.departureAt);
  const warning = journey.warnings[0] ?? theoreticalNotice(journey);
  const platform = firstTransit?.platform;

  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: colors.surface,
          borderColor: colors.line,
          boxShadow: `0 4px 14px ${colors.shadow}`,
        },
      ]}>
      <View style={styles.summary}>
        <JourneyLegStrip journey={journey} />
        <View style={styles.durationBlock}>
          <Text selectable style={[styles.duration, { color: colors.ink }]}>
            {duration}
          </Text>
          <Text style={[styles.durationUnit, { color: colors.muted }]}>min</Text>
        </View>
      </View>

      <Text numberOfLines={1} selectable style={[styles.route, { color: colors.ink }]}>
        {routeTitle(firstTransit?.from.name, lastTransit?.to.name)}
      </Text>

      {warning ? (
        <View style={styles.warning}>
          {firstTransit?.route ? (
            <LineBadge route={firstTransit.route} size={22} />
          ) : (
            <SymbolIcon color={colors.critical} name="exclamationmark.circle.fill" size={22} />
          )}
          <Text selectable style={[styles.warningText, { color: colors.muted }]}>
            {warning}
          </Text>
        </View>
      ) : null}

      <View style={[styles.footer, { borderTopColor: colors.line }]}>
        <View style={styles.departure}>
          <View style={[styles.departureDot, { backgroundColor: colors.primary }]} />
          <Text selectable style={[styles.departureText, { color: colors.muted }]}>
            Départ {departure}{platform ? ` · quai ${platform}` : ''}
          </Text>
        </View>
        <Pressable
          accessibilityLabel={`Choisir l’itinéraire de ${duration} minutes`}
          accessibilityRole="button"
          onPress={onPress}
          style={({ pressed }) => [
            styles.action,
            { backgroundColor: colors.primary },
            pressed && styles.pressed,
          ]}>
          <SymbolIcon color={colors.surface} name="location.north.fill" size={15} />
          <Text style={[styles.actionText, { color: colors.surface }]}>Y aller</Text>
        </Pressable>
      </View>
    </View>
  );
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit' }).format(
    new Date(value)
  );
}

function routeTitle(from?: string, to?: string) {
  if (from && to) return `${from} → ${to}`;
  return 'Itinéraire à pied';
}

function theoreticalNotice(journey: Journey) {
  return journey.status === 'theoretical'
    ? 'Horaires théoriques — vérifiez les perturbations sur place.'
    : undefined;
}

const styles = StyleSheet.create({
  card: {
    gap: 18,
    paddingHorizontal: 22,
    paddingTop: 24,
    paddingBottom: 18,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 28,
    borderCurve: 'continuous',
  },
  summary: {
    minHeight: 50,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  durationBlock: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 3,
  },
  duration: {
    fontFamily: 'Inter_700Bold',
    fontSize: 47,
    lineHeight: 50,
    letterSpacing: -2.2,
    fontVariant: ['tabular-nums'],
  },
  durationUnit: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 18,
  },
  route: {
    fontFamily: 'Inter_700Bold',
    fontSize: 18,
    lineHeight: 23,
    letterSpacing: -0.35,
  },
  warning: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  warningText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    lineHeight: 21,
  },
  footer: {
    minHeight: 63,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
    paddingTop: 16,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  departure: {
    minWidth: 0,
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  departureDot: { width: 8, height: 8, borderRadius: 4 },
  departureText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    lineHeight: 20,
    fontVariant: ['tabular-nums'],
  },
  action: {
    minWidth: 120,
    minHeight: 48,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingHorizontal: 18,
    borderRadius: 24,
  },
  actionText: { fontFamily: 'Inter_700Bold', fontSize: 16 },
  pressed: { opacity: 0.65 },
});
