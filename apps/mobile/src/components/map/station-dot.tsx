import { StyleSheet, View } from 'react-native';

type StationDotProps = {
  /** The colour of the line the dot sits on. */
  color: string;
  /** Interchanges read as slightly bigger dots. */
  interchange: boolean;
};

/** The round station mark, shared by the line view and the whole-network view. */
export function StationDot({ color, interchange }: StationDotProps) {
  return (
    <View
      style={[styles.dot, interchange && styles.interchange, { backgroundColor: color }]}
    />
  );
}

const styles = StyleSheet.create({
  dot: {
    width: 7.5,
    height: 7.5,
    borderRadius: 3.75,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.9)',
  },
  interchange: {
    width: 9.5,
    height: 9.5,
    borderRadius: 4.75,
    borderWidth: 1.25,
  },
});
