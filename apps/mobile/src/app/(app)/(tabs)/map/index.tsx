import { useRouter } from 'expo-router';
import { useEffect } from 'react';

import { MetroMapScreen } from '@/components/map/metro-map-screen';

export default function MapScreen() {
  const router = useRouter();

  useEffect(() => {
    router.push('/map/overview');
  }, [router]);

  return <MetroMapScreen />;
}
