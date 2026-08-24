import { env } from '../../env';
import { fetchJsonOrNull } from '../../http/fetch-json-or-null';

const VELIB_TIMEOUT_MS = 3_000;

export async function fetchVelibFeeds() {
  const [information, status] = await Promise.all([
    fetchJsonOrNull(new URL(env.VELIB_STATION_INFORMATION_URL), {
      timeoutMs: VELIB_TIMEOUT_MS,
      logLabel: '[velib] station_information',
    }),
    fetchJsonOrNull(new URL(env.VELIB_STATION_STATUS_URL), {
      timeoutMs: VELIB_TIMEOUT_MS,
      logLabel: '[velib] station_status',
    }),
  ]);

  return information === null || status === null ? null : { information, status };
}
