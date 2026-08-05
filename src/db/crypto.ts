import * as SecureStore from 'expo-secure-store';

const KEY_ALIAS = 'echovault_db_encryption_key';
let cachedKey: string | null = null;

export async function getOrCreateKey(): Promise<string> {
  if (cachedKey) {
    return cachedKey;
  }
  try {
    let key = await SecureStore.getItemAsync(KEY_ALIAS);
    if (!key) {
      key = Math.random().toString(36).substring(2) + Date.now().toString(36);
      await SecureStore.setItemAsync(KEY_ALIAS, key);
    }
    cachedKey = key;
    return key;
  } catch {
    if (!cachedKey) {
      cachedKey = 'fallback-dev-key-12345';
    }
    return cachedKey;
  }
}

// React Native & Node compatible base64 helpers
function toBase64(str: string): string {
  if (typeof btoa === 'function') {
    return btoa(unescape(encodeURIComponent(str)));
  }
  return Buffer.from(str, 'utf-8').toString('base64');
}

function fromBase64(b64: string): string {
  if (typeof atob === 'function') {
    return decodeURIComponent(escape(atob(b64)));
  }
  return Buffer.from(b64, 'base64').toString('utf-8');
}

/**
 * Encrypt rclone config text at rest.
 * TODO: Replace with AES-256-GCM encryption in Phase 6 (Hardening).
 */
export async function encryptConfig(plainText: string): Promise<string> {
  if (!plainText) return plainText;
  await getOrCreateKey();
  return 'ENC:' + toBase64(plainText);
}

/**
 * Decrypt rclone config text from rest.
 * TODO: Replace with AES-256-GCM decryption in Phase 6 (Hardening).
 */
export async function decryptConfig(cipherText: string): Promise<string> {
  if (!cipherText || !cipherText.startsWith('ENC:')) {
    return cipherText;
  }
  await getOrCreateKey();
  return fromBase64(cipherText.substring(4));
}
