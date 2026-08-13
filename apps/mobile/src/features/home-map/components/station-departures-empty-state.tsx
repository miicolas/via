import { StyleSheet, Text, View } from 'react-native';

import { Symbol } from '@/components/symbol';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type StationDeparturesEmptyStateProps = {
  expanded: boolean;
};

export function StationDeparturesEmptyState({
  expanded,
}: StationDeparturesEmptyStateProps) {
  const { colors } = useHomeMapTheme();

  return (
    <View style={[styles.container, expanded ? styles.expandedContainer : styles.compactContainer]}>
      <View style={[styles.content, expanded ? styles.expandedContent : styles.compactContent]}>
        <View
          style={[
            styles.iconBadge,
            expanded ? styles.expandedIconBadge : styles.compactIconBadge,
            {
              backgroundColor: colors.accentSoft,
              boxShadow: `0 1px 3px ${colors.shadow}`,
            },
          ]}>
          <Symbol
            animation={{ effect: { type: 'pulse' }, repeating: true }}
            color={colors.primary}
            name="airplaneseat"
            size={expanded ? 30 : 24}
          />
        </View>

        <View style={styles.copy}>
          <Text
            selectable
            style={[
              styles.title,
              expanded ? styles.expandedTitle : styles.compactTitle,
              { color: colors.ink },
            ]}>
            Aucun passage à venir
          </Text>
          {expanded ? (
            <Text selectable style={[styles.description, { color: colors.muted }]}>
              Aucun prochain passage n’est annoncé à cette station pour le moment.
            </Text>
          ) : null}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  compactContainer: { paddingVertical: 8 },
  expandedContainer: { paddingVertical: 32 },
  content: {
    alignItems: 'center',
    alignSelf: 'center',
    maxWidth: 330,
    width: '100%',
  },
  compactContent: { gap: 12 },
  expandedContent: { gap: 18 },
  iconBadge: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  compactIconBadge: {
    width: 52,
    height: 52,
    borderRadius: 26,
  },
  expandedIconBadge: {
    width: 68,
    height: 68,
    borderRadius: 34,
  },
  copy: {
    alignItems: 'center',
    gap: 6,
  },
  title: {
    fontFamily: 'Archivo_800ExtraBold',
    letterSpacing: -0.5,
    textAlign: 'center',
  },
  compactTitle: {
    fontSize: 20,
    lineHeight: 24,
  },
  expandedTitle: {
    fontSize: 23,
    lineHeight: 28,
  },
  description: {
    maxWidth: 300,
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
  },
});
