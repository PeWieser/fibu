/**
 * RcloneModule.ts — App-facing facade over the rclone Expo local module.
 *
 * Phase 4 (Sync Engine) imports from this file exclusively and must not reach
 * into `modules/rclone/src` directly. This keeps the public API stable even
 * if the underlying module is refactored.
 */

import { RcloneService } from '../../modules/rclone/src/RcloneService';

// Re-export all types so callers only need one import path.
export type {
  ProviderType,
  RemoteSpec,
  SyncOptions,
  QuotaInfo,
  RcloneConfig,
  AuthorizeResult,
  RcloneProgressEvent,
  RcloneJobEvent,
} from '../../modules/rclone/src/RcloneTypes';

export type { EventSubscription } from '../../modules/rclone/src/RcloneService';

export type {
  NativeRcloneModule,
  RcloneEventMap,
} from '../../modules/rclone/src/RcloneNativeModule';

// Singleton service instance used throughout the app.
const service = new RcloneService();

/**
 * `RcloneModule` is the singleton bridge the app interacts with.
 *
 * Public surface mirrors the original `RcloneBridge` class and is extended
 * with event helpers and the OAuth exchange step.
 */
export const RcloneModule = {
  // -------------------------------------------------------------------------
  // Config
  // -------------------------------------------------------------------------
  getConfig: (): ReturnType<RcloneService['getConfig']> => service.getConfig(),

  addRemote: (
    ...args: Parameters<RcloneService['addRemote']>
  ): ReturnType<RcloneService['addRemote']> => service.addRemote(...args),

  deleteRemote: (
    ...args: Parameters<RcloneService['deleteRemote']>
  ): ReturnType<RcloneService['deleteRemote']> => service.deleteRemote(...args),

  createUnionRemote: (
    ...args: Parameters<RcloneService['createUnionRemote']>
  ): ReturnType<RcloneService['createUnionRemote']> => service.createUnionRemote(...args),

  createCryptRemote: (
    ...args: Parameters<RcloneService['createCryptRemote']>
  ): ReturnType<RcloneService['createCryptRemote']> => service.createCryptRemote(...args),

  // -------------------------------------------------------------------------
  // Sync
  // -------------------------------------------------------------------------
  sync: (
    ...args: Parameters<RcloneService['sync']>
  ): ReturnType<RcloneService['sync']> => service.sync(...args),

  // -------------------------------------------------------------------------
  // Storage
  // -------------------------------------------------------------------------
  about: (
    ...args: Parameters<RcloneService['about']>
  ): ReturnType<RcloneService['about']> => service.about(...args),

  deleteRemotePath: (
    ...args: Parameters<RcloneService['deleteRemotePath']>
  ): ReturnType<RcloneService['deleteRemotePath']> => service.deleteRemotePath(...args),

  // -------------------------------------------------------------------------
  // OAuth — `authorize` is the Phase-4-facing name; maps to startOAuthFlow.
  // -------------------------------------------------------------------------
  authorize: (
    provider: string,
  ): ReturnType<RcloneService['startOAuthFlow']> => service.startOAuthFlow(provider),

  startOAuthFlow: (
    ...args: Parameters<RcloneService['startOAuthFlow']>
  ): ReturnType<RcloneService['startOAuthFlow']> => service.startOAuthFlow(...args),

  exchangeOAuthCode: (
    ...args: Parameters<RcloneService['exchangeOAuthCode']>
  ): ReturnType<RcloneService['exchangeOAuthCode']> => service.exchangeOAuthCode(...args),

  // -------------------------------------------------------------------------
  // Event subscriptions
  // -------------------------------------------------------------------------
  subscribeToProgress: (
    ...args: Parameters<RcloneService['subscribeToProgress']>
  ): ReturnType<RcloneService['subscribeToProgress']> =>
    service.subscribeToProgress(...args),

  subscribeToJobStatus: (
    ...args: Parameters<RcloneService['subscribeToJobStatus']>
  ): ReturnType<RcloneService['subscribeToJobStatus']> =>
    service.subscribeToJobStatus(...args),

  subscribeToAuthCallback: (
    ...args: Parameters<RcloneService['subscribeToAuthCallback']>
  ): ReturnType<RcloneService['subscribeToAuthCallback']> =>
    service.subscribeToAuthCallback(...args),
} as const;
