import * as SecureStore from 'expo-secure-store';
import * as Crypto from 'expo-crypto';
import { Logger } from '../utils/logger';

const KEY_ALIAS = 'fibu_db_key';
let cachedKey: CryptoKey | null = null;

// Convert base64 string to Uint8Array
function base64ToUint8Array(base64: string): Uint8Array {
  if (typeof atob === 'function') {
    const binaryString = atob(base64);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes;
  }
  return new Uint8Array(Buffer.from(base64, 'base64'));
}

// Convert Uint8Array to base64 string
function uint8ArrayToBase64(bytes: Uint8Array): string {
  if (typeof btoa === 'function') {
    let binary = '';
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }
  return Buffer.from(bytes).toString('base64');
}

export async function getOrCreateKey(): Promise<CryptoKey | null> {
  if (cachedKey) {
    return cachedKey;
  }
  try {
    let keyBase64 = await SecureStore.getItemAsync(KEY_ALIAS);
    if (!keyBase64) {
      const randomBytes = await Crypto.getRandomBytesAsync(32);
      keyBase64 = uint8ArrayToBase64(randomBytes);
      await SecureStore.setItemAsync(KEY_ALIAS, keyBase64);
    }
    const rawKey = base64ToUint8Array(keyBase64);
    if (typeof global.crypto === 'undefined' || typeof global.crypto.subtle === 'undefined') {
      Logger.warn('Web Crypto API not available. Encryption disabled.');
      return null;
    }
    cachedKey = await global.crypto.subtle.importKey(
      'raw',
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      rawKey as any,
      { name: 'AES-GCM' },
      false,
      ['encrypt', 'decrypt']
    );
    return cachedKey;
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    Logger.warn(`SecureStore or Crypto API not available. Encryption disabled: ${errMsg}`);
    return null;
  }
}

export async function encrypt(plainText: string): Promise<string> {
  if (!plainText) return plainText;
  const key = await getOrCreateKey();
  if (!key) return plainText;

  const iv = await Crypto.getRandomBytesAsync(12);
  const encoder = new TextEncoder();
  const encodedText = encoder.encode(plainText);

  const cipherTextBuffer = await global.crypto.subtle.encrypt(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    { name: 'AES-GCM', iv: iv as any },
    key,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    encodedText as any
  );

  const cipherTextArray = new Uint8Array(cipherTextBuffer);
  const combined = new Uint8Array(iv.length + cipherTextArray.length);
  combined.set(iv);
  combined.set(cipherTextArray, iv.length);

  return uint8ArrayToBase64(combined);
}

export async function decrypt(cipherText: string): Promise<string> {
  if (!cipherText) return cipherText;
  
  const key = await getOrCreateKey();
  if (!key) return cipherText;

  try {
    const combined = base64ToUint8Array(cipherText);
    const iv = combined.slice(0, 12);
    const data = combined.slice(12);

    const decryptedBuffer = await global.crypto.subtle.decrypt(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      { name: 'AES-GCM', iv: iv as any },
      key,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      data as any
    );

    const decoder = new TextDecoder();
    return decoder.decode(decryptedBuffer);
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    Logger.error(`Decryption failed: ${errMsg}`);
    throw new Error('DecryptionFailed: Unable to decrypt stored configuration');
  }
}

export const encryptConfig = encrypt;
export const decryptConfig = decrypt;
