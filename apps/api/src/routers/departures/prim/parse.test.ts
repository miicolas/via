import { expect, test } from 'bun:test';

import { parseStopMonitoring } from './parse';

/**
 * Hand-built from the SIRI Lite shapes the PRIM doc describes. The spike
 * script saves a real payload into `__fixtures__/` — swap it in here once the
 * API key has been exercised.
 */
const delivery = (visits: unknown[]) => ({
  Siri: { ServiceDelivery: { StopMonitoringDelivery: [{ MonitoredStopVisit: visits }] } },
});

const visit = {
  MonitoredVehicleJourney: {
    LineRef: { value: 'STIF:Line::C01371:' },
    DestinationName: [{ value: 'Château de Vincennes' }],
    MonitoredCall: {
      ExpectedDepartureTime: '2026-08-12T18:50:12+02:00',
      ExpectedArrivalTime: '2026-08-12T18:49:42+02:00',
    },
  },
};

test('a nominal visit is normalized with departure time first', () => {
  expect(parseStopMonitoring(delivery([visit]))).toEqual([
    {
      routeId: 'IDFM:C01371',
      destination: 'Château de Vincennes',
      expectedAt: '2026-08-12T18:50:12+02:00',
    },
  ]);
});

test('arrival time fills in when departure time is missing', () => {
  const arrivalOnly = structuredClone(visit) as any;
  delete arrivalOnly.MonitoredVehicleJourney.MonitoredCall.ExpectedDepartureTime;

  expect(parseStopMonitoring(delivery([arrivalOnly]))[0]?.expectedAt).toBe(
    '2026-08-12T18:49:42+02:00'
  );
});

test('a malformed visit drops without taking the rest down', () => {
  const noLine = structuredClone(visit) as any;
  delete noLine.MonitoredVehicleJourney.LineRef;

  expect(parseStopMonitoring(delivery([noLine, visit]))).toHaveLength(1);
});

test('bare strings and unwrapped objects parse like enveloped ones', () => {
  const bare = {
    MonitoredVehicleJourney: {
      LineRef: 'STIF:Line::C01381:',
      DestinationName: { value: 'Châtelet' },
      MonitoredCall: { ExpectedDepartureTime: '2026-08-12T19:01:00+02:00' },
    },
  };

  expect(parseStopMonitoring(delivery([bare]))).toEqual([
    { routeId: 'IDFM:C01381', destination: 'Châtelet', expectedAt: '2026-08-12T19:01:00+02:00' },
  ]);
});

test('an empty or alien body parses to no visits', () => {
  expect(parseStopMonitoring(null)).toEqual([]);
  expect(parseStopMonitoring({})).toEqual([]);
  expect(parseStopMonitoring({ Siri: { ServiceDelivery: {} } })).toEqual([]);
});
