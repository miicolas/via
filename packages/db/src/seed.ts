import { client, db, stops } from './index';

const SAMPLE = [
  { name: 'Châtelet', location: { lon: 2.3470, lat: 48.8583 } },
  { name: 'Gare de Lyon', location: { lon: 2.3731, lat: 48.8443 } },
  { name: 'Nation', location: { lon: 2.3958, lat: 48.8483 } },
  { name: 'La Défense', location: { lon: 2.2378, lat: 48.8918 } },
];

await db.delete(stops);
await db.insert(stops).values(SAMPLE);

console.log(`Seeded ${SAMPLE.length} stops.`);

await client.end();
