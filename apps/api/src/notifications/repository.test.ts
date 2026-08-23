import { expect, test } from "bun:test";

import { notificationDeviceLockKey } from "./repository";

test("notification device advisory lock keys are valid PostgreSQL text", () => {
  const key = notificationDeviceLockKey({
    bundleId: "dev.via.app",
    environment: "sandbox",
    deviceToken: "aa".repeat(32),
  });

  expect(key).not.toContain('\u0000');
});
