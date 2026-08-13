import type { JourneySection } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type JourneyStepProps = { section: JourneySection; last: boolean };

export function JourneyStep({ section, last }: JourneyStepProps) {
  const { colors } = useHomeMapTheme();
  const minutes = Math.max(1, Math.round(section.durationSeconds / 60));
  const icon = section.type === 'walk' ? 'figure.walk' : section.type === 'transfer' ? 'arrow.triangle.branch' : 'tram.fill';
  return (
    <View style={styles.row}>
      <View style={styles.rail}>
        <View style={[styles.dot, { backgroundColor: section.route?.color ?? colors.primary }]} />
        {!last ? <View style={[styles.line, { backgroundColor: colors.line }]} /> : null}
      </View>
      <View style={styles.body}>
        <View style={styles.top}>
          {section.route ? <LineBadge route={section.route} size={28} /> : <Text style={[styles.icon, { color: colors.primary }]}>{icon === 'figure.walk' ? '⌁' : '↗'}</Text>}
          <View style={styles.copy}>
            <Text selectable style={[styles.title, { color: colors.ink }]}>
              {section.type === 'walk' ? 'Marche' : section.type === 'transfer' ? 'Correspondance' : section.route?.longName ?? 'Transport'}
            </Text>
            <Text numberOfLines={1} style={[styles.subtitle, { color: colors.muted }]}>
              {section.type === 'transit' ? `${section.from.name} → ${section.to.name}` : `${section.from.name} → ${section.to.name}`}
            </Text>
          </View>
          <Text style={[styles.duration, { color: colors.muted }]}>{minutes} min</Text>
        </View>
        {section.direction ? <Text style={[styles.direction, { color: colors.primary }]}>{section.direction}</Text> : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', minHeight: 78 },
  rail: { width: 28, alignItems: 'center' },
  dot: { width: 12, height: 12, marginTop: 9, borderRadius: 6, borderCurve: 'continuous' },
  line: { flex: 1, width: 2, marginVertical: 4 },
  body: { flex: 1, gap: 5, paddingBottom: 16, paddingLeft: 8 },
  top: { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  icon: { width: 28, fontSize: 26, lineHeight: 28, textAlign: 'center' },
  copy: { flex: 1, gap: 2 },
  title: { fontFamily: 'Inter_700Bold', fontSize: 15, lineHeight: 19 },
  subtitle: { fontFamily: 'Inter_400Regular', fontSize: 13, lineHeight: 17 },
  duration: { fontFamily: 'Inter_600SemiBold', fontSize: 13, fontVariant: ['tabular-nums'] },
  direction: { fontFamily: 'Inter_600SemiBold', fontSize: 12, paddingLeft: 38 },
});
