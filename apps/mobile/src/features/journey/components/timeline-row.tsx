import type { ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';

import { GlassSurface } from '@/components/glass-surface';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyTimelineRowProps = {
  children: ReactNode;
  /** Marker tint: dot fill, or ring border around a hollow centre. */
  color: string;
  last: boolean;
  marker: 'dot' | 'ring';
  /** Replaces the geometric marker, for example with the boarded line's logo. */
  markerContent?: ReactNode;
};

/** The rail every timeline step hangs from: a marker and, until the last row, a spine. */
export function JourneyTimelineRow({
  children,
  color,
  last,
  marker,
  markerContent,
}: JourneyTimelineRowProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.row}>
      <View style={styles.rail}>
        <View style={styles.markerSlot}>
          {markerContent ?? (
            <View
              style={[
                styles.marker,
                marker === 'dot'
                  ? { backgroundColor: color }
                  : { backgroundColor: colors.surface, borderWidth: 2, borderColor: color },
              ]}
            />
          )}
        </View>
        {!last ? <View style={[styles.spine, { backgroundColor: colors.line }]} /> : null}
      </View>
      <GlassSurface variant="card" style={[styles.body, last && styles.lastBody]}>
        {children}
      </GlassSurface>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row' },
  rail: { width: 36, alignItems: 'center' },
  markerSlot: { height: 30, marginTop: 8, alignItems: 'center', justifyContent: 'center' },
  marker: { width: 12, height: 12, borderRadius: 6, borderCurve: 'continuous' },
  spine: { flex: 1, width: 2, marginVertical: 4, borderRadius: 1 },
  body: {
    minWidth: 0,
    flex: 1,
    gap: 4,
    marginBottom: 10,
    marginLeft: 8,
    paddingVertical: 11,
    paddingHorizontal: 12,
    borderRadius: 18,
  },
  lastBody: { marginBottom: 0 },
});
