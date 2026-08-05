/**
 * RcloneService.ts — Typed service that translates high-level operations into
 * rclone RC (remote-control) calls via the native module.
 *
 * All methods currently throw NotImplemented because the librclone native
 * bindings ship in Phase 3b. Phase 4 (Sync Engine) codes against this
 * interface and can be developed independently.
 */

import type { EventSubscription } from 'expo-modules-core';
import { eventEmitter } from './RcloneNativeModule';
import type {
  RcloneConfig,
  RemoteSpec,
  SyncOptions,
  QuotaInfo,
  AuthorizeResult,
  RcloneProgressEvent,
  RcloneJobEvent,
} from './RcloneTypes';

/** Subscription handle returned by subscribe helpers. */
export type { EventSubscription };

export class RcloneService {
  // -------------------------------------------------------------------------
  // Config operations
  // -------------------------------------------------------------------------

  /** Return the parsed rclone config (maps to `config/dump` RC call). */
  async getConfig(): Promise<RcloneConfig> {
    throw new Error('NotImplemented: RcloneService.getConfig');
  }

  /** Add a new remote to rclone config (maps to `config/create`). */
  async addRemote(_spec: RemoteSpec): Promise<void> {
    throw new Error('NotImplemented: RcloneService.addRemote');
  }

  /** Remove a remote from rclone config (maps to `config/delete`). */
  async deleteRemote(_name: string): Promise<void> {
    throw new Error('NotImplemented: RcloneService.deleteRemote');
  }

  /**
   * Create a union remote that aggregates several remotes.
   * Maps to `config/create` with type=union.
   * @returns The generated union remote name.
   */
  async createUnionRemote(_names: string[]): Promise<string> {
    throw new Error('NotImplemented: RcloneService.createUnionRemote');
  }

  /**
   * Create a crypt remote on top of an existing remote.
   * Maps to `config/create` with type=crypt.
   * @returns The generated crypt remote name.
   */
  async createCryptRemote(_baseName: string, _password: string): Promise<string> {
    throw new Error('NotImplemented: RcloneService.createCryptRemote');
  }

  // -------------------------------------------------------------------------
  // Sync operations
  // -------------------------------------------------------------------------

  /**
   * Start an async sync job (maps to `sync/sync`).
   * @returns Opaque job ID that can be used to track progress events.
   */
  async sync(
    _sourceDir: string,
    _targetRemote: string,
    _options?: SyncOptions,
  ): Promise<string> {
    throw new Error('NotImplemented: RcloneService.sync');
  }

  // -------------------------------------------------------------------------
  // Storage operations
  // -------------------------------------------------------------------------

  /** Query quota for a remote (maps to `operations/about`). */
  async about(_remoteName: string): Promise<QuotaInfo> {
    throw new Error('NotImplemented: RcloneService.about');
  }

  /** Purge a path on a remote (maps to `operations/purge`). */
  async deleteRemotePath(_remoteName: string, _path: string): Promise<void> {
    throw new Error('NotImplemented: RcloneService.deleteRemotePath');
  }

  // -------------------------------------------------------------------------
  // OAuth
  // -------------------------------------------------------------------------

  /**
   * Start the OAuth2 authorisation flow for a provider.
   * @returns The authorisation URL the user must open in a browser.
   */
  async startOAuthFlow(_provider: string): Promise<string> {
    throw new Error('NotImplemented: RcloneService.startOAuthFlow');
  }

  /**
   * Exchange an OAuth2 code for an access token.
   * @returns Parsed AuthorizeResult containing the token JSON.
   */
  async exchangeOAuthCode(_provider: string, _code: string): Promise<AuthorizeResult> {
    throw new Error('NotImplemented: RcloneService.exchangeOAuthCode');
  }

  // -------------------------------------------------------------------------
  // Event subscriptions
  // -------------------------------------------------------------------------

  /**
   * Subscribe to progress events emitted during active sync jobs.
   * @returns Subscription handle — call `.remove()` to unsubscribe.
   */
  subscribeToProgress(
    cb: (event: RcloneProgressEvent) => void,
  ): EventSubscription {
    return eventEmitter.addListener('onProgress', cb);
  }

  /**
   * Subscribe to job status change events (running → success | error).
   * @returns Subscription handle — call `.remove()` to unsubscribe.
   */
  subscribeToJobStatus(
    cb: (event: RcloneJobEvent) => void,
  ): EventSubscription {
    return eventEmitter.addListener('onJobStatusChange', cb);
  }

  /**
   * Subscribe to OAuth callback events from the native layer.
   * @returns Subscription handle — call `.remove()` to unsubscribe.
   */
  subscribeToAuthCallback(
    cb: (event: { provider: string; url: string }) => void,
  ): EventSubscription {
    return eventEmitter.addListener('onAuthCallback', cb);
  }
}
