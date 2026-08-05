/**
 * RcloneNativeModule.ts — Expo Modules API native interface for the Rclone module.
 *
 * `requireNativeModule('Rclone')` resolves to the native layer registered by
 * the Expo Modules API runtime (iOS/Android). In the test/web environment it
 * will throw — all callers must guard via RcloneService which throws
 * NotImplemented stubs instead.
 */

import { requireNativeModule, EventEmitter } from 'expo-modules-core';
import type { RcloneProgressEvent, RcloneJobEvent } from './RcloneTypes';

// ---------------------------------------------------------------------------
// Native method surface
// ---------------------------------------------------------------------------

/** Raw interface exposed by the native Rclone Expo Module. */
export interface NativeRcloneModule {
  /** Initialise librclone runtime. Must be called once before any RPC. */
  initialize(): Promise<void>;

  /**
   * Execute a raw rclone RC (remote-control) call.
   * @param method - RC method path, e.g. "config/dump" or "sync/sync".
   * @param params - JSON-serialised parameter object.
   * @returns JSON-serialised response object.
   */
  rpcCall(method: string, params: string): Promise<string>;

  /**
   * Start an OAuth2 flow for the given provider.
   * @param provider - rclone provider name, e.g. "drive".
   * @returns The authorisation URL the user must open.
   */
  startOAuthFlow(provider: string): Promise<string>;

  /**
   * Exchange an OAuth2 authorisation code for a token.
   * @param provider - rclone provider name.
   * @param code    - Code received from the OAuth redirect.
   * @returns JSON-serialised token blob.
   */
  exchangeOAuthCode(provider: string, code: string): Promise<string>;
}

// ---------------------------------------------------------------------------
// Event map
// ---------------------------------------------------------------------------

/** Typed event map for the rclone EventEmitter. */
export type RcloneEventMap = {
  /** Fired periodically during an active sync job. */
  onProgress: (event: RcloneProgressEvent) => void;
  /** Fired when a job transitions to success or error. */
  onJobStatusChange: (event: RcloneJobEvent) => void;
  /** Fired when the native layer receives an OAuth callback URL. */
  onAuthCallback: (event: { provider: string; url: string }) => void;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- EventsMap constraint requires any[] parameters
  [key: string]: ((...args: any[]) => void);
};

// ---------------------------------------------------------------------------
// Module instances
// ---------------------------------------------------------------------------

/**
 * The raw native module.
 *
 * NOTE: `requireNativeModule` throws at runtime if the native module is not
 * registered (e.g. in Jest / web). RcloneService wraps every call in a
 * NotImplemented guard so this module is never invoked in unsupported
 * environments.
 */
export const nativeModule: NativeRcloneModule =
  requireNativeModule<NativeRcloneModule>('Rclone');

/** Typed EventEmitter bound to the native Rclone module.
 *
 * As of Expo SDK 52 the native module itself is an EventEmitter.
 * We construct a typed wrapper here so addListener calls are type-checked.
 * When the native module is not registered (Jest/web), the mock EventEmitter
 * from the test setup is used instead.
 */
export const eventEmitter = new EventEmitter<RcloneEventMap>();

