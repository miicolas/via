import type { RouteBadge } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { hideOpenViaMarkup } from '@/features/chat/model/hide-open-via-markup';
import { normalizeViaMarkup } from '@/features/chat/model/normalize-via-markup';
import { parseViaMarkup } from '@/features/chat/model/parse-via-markup';
import { useAppTheme } from '@/hooks/use-app-theme';

type ViaRichTextProps = {
  /** Badges to resolve `{{11}}` tokens against; unknown lines fall back to text. */
  routes: RouteBadge[];
  streaming: boolean;
  text: string;
};

/** Via's answer with inline line badges and underlined places, safe to render mid-stream. */
export function ViaRichText({ routes, streaming, text }: ViaRichTextProps) {
  const { colors } = useAppTheme();
  const clean = normalizeViaMarkup(text);
  const segments = parseViaMarkup(streaming ? hideOpenViaMarkup(clean) : clean);

  return (
    <Text style={[styles.text, { color: colors.ink }]}>
      {segments.map((segment, index) => {
        if (segment.type === 'line') {
          const route = resolveRoute(routes, segment.value);
          if (route) {
            return (
              <View key={index} style={styles.badge}>
                <LineBadge route={route} size={24} />
              </View>
            );
          }
          return (
            <Text key={index} style={styles.lineFallback}>
              {segment.value.split(':').at(-1)}
            </Text>
          );
        }
        if (segment.type === 'place') {
          return (
            <Text key={index} style={styles.place}>
              {segment.value}
            </Text>
          );
        }
        return <Text key={index}>{segment.value}</Text>;
      })}
      {streaming ? <View style={[styles.caret, { backgroundColor: colors.primary }]} /> : null}
    </Text>
  );
}

/** Collisions exist across networks ("1" is a metro and a bus): trust the hint, then the heavier mode. */
const MODE_PRIORITY = ['metro', 'rer', 'tram', 'bus'];

function resolveRoute(routes: RouteBadge[], token: string): RouteBadge | undefined {
  const [hint, shortName] = token.includes(':')
    ? (token.split(':') as [string, string])
    : [undefined, token];
  const candidates = routes.filter(
    (candidate) => candidate.shortName.toLowerCase() === shortName.toLowerCase()
  );
  if (hint) {
    const hinted = candidates.find((candidate) => candidate.mode === hint);
    if (hinted) return hinted;
  }
  return (
    MODE_PRIORITY.flatMap((mode) => candidates.filter((candidate) => candidate.mode === mode))[0] ??
    candidates[0]
  );
}

const styles = StyleSheet.create({
  text: { fontFamily: 'Archivo_700Bold', fontSize: 21, lineHeight: 32 },
  badge: { transform: [{ translateY: 1 }] },
  lineFallback: { fontFamily: 'Archivo_700Bold' },
  place: { textDecorationLine: 'underline' },
  caret: { width: 9, height: 22, borderRadius: 3, transform: [{ translateY: 3 }] },
});
