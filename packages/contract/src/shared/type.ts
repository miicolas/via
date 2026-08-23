import * as z from 'zod';

import {
  accessibilityConditionSchema,
  coordinateSchema,
  elevatorReasonSchema,
  elevatorStatusSchema,
  networkModeSchema,
  routeBadgeSchema,
  sourceSnapshotStatusSchema,
  stationElevatorSchema,
  stationElevatorSnapshotSchema,
} from './schema';

export type AccessibilityCondition = z.infer<typeof accessibilityConditionSchema>;
export type Coordinate = z.infer<typeof coordinateSchema>;
export type ElevatorReason = z.infer<typeof elevatorReasonSchema>;
export type ElevatorStatus = z.infer<typeof elevatorStatusSchema>;
export type NetworkMode = z.infer<typeof networkModeSchema>;
export type RouteBadge = z.infer<typeof routeBadgeSchema>;
export type SourceSnapshotStatus = z.infer<typeof sourceSnapshotStatusSchema>;
export type StationElevator = z.infer<typeof stationElevatorSchema>;
export type StationElevatorSnapshot = z.infer<typeof stationElevatorSnapshotSchema>;
