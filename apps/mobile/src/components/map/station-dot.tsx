import { StyleSheet, View } from 'react-native';

type StationDotProps = {
  /** The colour of the line the dot sits on. */
  color: string;
};

/** A rounded line-colour block shown on the station's track. */
export function StationDot({ color }: StationDotProps) {
  return <View style={[styles.dot, { backgroundColor: color }]} />;
}

const styles = StyleSheet.create({
  dot: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderCurve: 'continuous',
    boxShadow: '0 1px 3px rgba(0,0,0,0.35)',
  },
});
