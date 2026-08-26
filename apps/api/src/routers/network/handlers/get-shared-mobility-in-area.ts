import { selectInArea } from '../../../geo/area';
import { implementer } from '../../../orpc/implementer';
import { getSharedMobilitySnapshot } from '../../shared-mobility/snapshot';
import { SHARED_MOBILITY_CACHE_CONTROL } from './network-cache-control';

export const getSharedMobilityInArea = implementer.network.sharedMobilityInArea.handler(
  async ({ input, context }) => {
    const snapshot = await getSharedMobilitySnapshot();
    context.resHeaders?.set('Cache-Control', SHARED_MOBILITY_CACHE_CONTROL);

    return {
      items: selectInArea(snapshot.items, input),
      sources: snapshot.sources,
    };
  }
);
