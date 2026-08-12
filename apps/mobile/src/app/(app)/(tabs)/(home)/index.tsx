import { Redirect, type Href } from 'expo-router';

const homeHref = '/map/overview' as Href;

export default function HomeRoute() {
  return <Redirect href={homeHref} />;
}
