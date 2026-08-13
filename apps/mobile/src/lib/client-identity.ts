import { requireOptionalNativeModule } from 'expo';

const STORAGE_KEY = 'via.anonymous-client-id';
let memoryId: string | undefined;
let pending: Promise<string> | undefined;

const hasSecureStore = requireOptionalNativeModule('ExpoSecureStore') !== null;

/** Stable anonymous identity used only to protect the shared IDFM quota. */
export function getClientIdentity(): Promise<string> {
  pending ??= loadClientIdentity();
  return pending;
}

async function loadClientIdentity() {
  if (memoryId) return memoryId;
  if (hasSecureStore) {
    try {
      const secureStore = await import('expo-secure-store');
      const stored = await secureStore.getItemAsync(STORAGE_KEY);
      if (stored) {
        memoryId = stored;
        return stored;
      }
    } catch {
      // An older development client can run before the native module is rebuilt.
    }
  }

  const generated = globalThis.crypto?.randomUUID?.() ?? `via-${Date.now()}-${Math.random()}`;
  memoryId = generated;
  if (hasSecureStore) {
    try {
      const secureStore = await import('expo-secure-store');
      await secureStore.setItemAsync(STORAGE_KEY, generated);
    } catch {
      // The server still has its IP fallback when secure storage is unavailable.
    }
  }
  return generated;
}
