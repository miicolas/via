/**
 * Prints the APNs device tokens registered for an account so a push can be sent
 * by hand from Apple's Push Notifications Console — the one way to exercise a
 * real device without going through the monitors, which fan out to every user.
 *
 * The token only appears once the app has both a signed-in account and the
 * notification permission: `--watch` waits for that instead of asking the
 * operator to re-run the query until it lands.
 */
import { desc, eq, or } from 'drizzle-orm';
import { client, db, notificationDevices, users } from '@via/db';

const WATCH_INTERVAL_MILLISECONDS = 3_000;

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const account = args.find((argument) => !argument.startsWith('--'));

async function listDevices() {
  const query = db
    .select({
      installationId: notificationDevices.installationId,
      deviceToken: notificationDevices.deviceToken,
      bundleId: notificationDevices.bundleId,
      environment: notificationDevices.environment,
      appVersion: notificationDevices.appVersion,
      osVersion: notificationDevices.osVersion,
      createdAt: notificationDevices.createdAt,
      lastSeenAt: notificationDevices.lastSeenAt,
      userId: users.id,
      email: users.email,
      isAnonymous: users.isAnonymous,
    })
    .from(notificationDevices)
    .innerJoin(users, eq(users.id, notificationDevices.userId))
    .orderBy(desc(notificationDevices.lastSeenAt));

  return account
    ? query.where(or(eq(users.id, account), eq(users.email, account)))
    : query;
}

type Device = Awaited<ReturnType<typeof listDevices>>[number];

function render(devices: readonly Device[]) {
  for (const device of devices) {
    console.log('');
    console.log(`  compte        ${device.email ?? device.userId}${device.isAnonymous ? ' (anonyme)' : ''}`);
    console.log(`  installation  ${device.installationId}`);
    console.log(`  bundle        ${device.bundleId}`);
    console.log(`  environnement ${device.environment}`);
    console.log(`  app / iOS     ${device.appVersion ?? '?'} / ${device.osVersion ?? '?'}`);
    console.log(`  vu le         ${device.lastSeenAt.toISOString()}`);
    console.log(`  device token  ${device.deviceToken}`);
  }
  console.log('');
  console.log('Push Notifications Console → https://developer.apple.com/notifications/push-notifications-console');
  console.log(`  Device Token = la ligne ci-dessus · Bundle ID = ${devices[0]?.bundleId ?? 'dev.via.app'}` +
    ` · Environment = ${devices[0]?.environment === 'sandbox' ? 'Sandbox' : 'Production'} · Push Type = Alert`);
}

const found = await listDevices();

if (found.length > 0) {
  render(found);
} else if (!watch) {
  console.log(
    account
      ? `Aucun appareil enregistré pour ${account}.`
      : 'Aucun appareil enregistré.',
  );
  console.log(
    "L'app n'envoie son token qu'avec un compte Apple connecté ET la permission notifications accordée.",
  );
  console.log('Relance avec --watch, puis ouvre l’app et accepte les notifications.');
} else {
  console.log('En attente du token — ouvre l’app, connecte-toi et accepte les notifications…');
  let devices = found;
  while (devices.length === 0) {
    await Bun.sleep(WATCH_INTERVAL_MILLISECONDS);
    devices = await listDevices();
  }
  render(devices);
}

await client.end();
