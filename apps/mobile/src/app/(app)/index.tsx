import { useRouter } from 'expo-router';
import { useEffect } from 'react';

import { MetroMapScreen } from '@/components/map/metro-map-screen';

export default function MapBackgroundRoute() {
  const router = useRouter();

  useEffect(() => {
    router.navigate('/map');
  }, [router]);

  return <MetroMapScreen />;
}
