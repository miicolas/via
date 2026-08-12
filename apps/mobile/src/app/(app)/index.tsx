import { Redirect, type Href } from 'expo-router';

const MAP_HREF = '/map' as Href;

export default function AppIndexRoute() {
  return <Redirect href={MAP_HREF} />;
}
