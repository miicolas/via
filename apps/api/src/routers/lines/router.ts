import { getLineDetail } from './handlers/get-line-detail';
import { getLineSearch } from './handlers/get-line-search';
import { getLineStatuses } from './handlers/get-line-statuses';

export const linesRouter = {
  statuses: getLineStatuses,
  search: getLineSearch,
  detail: getLineDetail,
};
