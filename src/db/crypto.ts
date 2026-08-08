import * as SecureStore from 'expo-secure-store';
import * as Crypto from 'expo-crypto';
import { Logger } from '../utils/logger';

const KEY_ALIAS = 'fibu_db_key';
let cachedKey: CryptoKey | null = null;

function base64ToUint8Array(base64: string): Uint8Array {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function getSubtle(): SubtleCrypto | null {
  // globalThis.crypto is available in React Native (Hermes) and browsers.
  // Avoids referencing the Node-only `global` or `Buffer` globals.
  const subtle = (globalThis as typeof globalThis & { crypto?: Crypto }).crypto?.subtle;
  return subtle ?? null;
}

export async function getOrCreateKey(): Promise<CryptoKey | null> {
  if (cachedKey) return cachedKey;

  const subtle = getSubtle();
  if (!subtle) {
    Logger.warn('Web Crypto API not available. Encryption disabled.');
    return null;
  }

  try {
    let keyBase64 = await SecureStore.getItemAsync(KEY_ALIAS);
    if (!keyBase64) {
      const randomBytes = await Crypto.getRandomBytesAsync(32);
      keyBase64 = uint8ArrayToBase64(randomBytes);
      await SecureStore.setItemAsync(KEY_ALIAS, keyBase64);
    }
    cachedKey = await subtle.importKey(
      'raw',
      base64ToUint8Array(keyBase64),
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

  const subtle = getSubtle()!;
  const iv = await Crypto.getRandomBytesAsync(12);
  const encodedText = new TextEncoder().encode(plainText);

  const cipherTextBuffer = await subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    encodedText
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
    const subtle = getSubtle()!;
    const combined = base64ToUint8Array(cipherText);
    const iv = combined.slice(0, 12);
    const data = combined.slice(12);

    const decryptedBuffer = await subtle.decrypt(
      { name: 'AES-GCM', iv },
      key,
      data
    );

    return new TextDecoder().decode(decryptedBuffer);
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    Logger.error(`Decryption failed: ${errMsg}`);
    throw new Error('DecryptionFailed: Unable to decrypt stored configuration');
  }
}

export const encryptConfig = encrypt;
export const decryptConfig = decrypt;
