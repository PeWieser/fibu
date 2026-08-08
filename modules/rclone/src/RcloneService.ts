/**
 * RcloneService.ts — Typed service that translates high-level operations into
 * rclone RC (remote-control) HTTP calls via the native module.
 *
 * The native module starts `rclone rcd --rc-no-auth` on 127.0.0.1:5572 and
 * exposes rpcCall() / startOAuthFlow() / exchangeOAuthCode() as async bridge
 * methods. All public methods here encode params to JSON, call the bridge, and
 * decode the JSON response.
 */

import type { EventSubscription } from 'expo-modules-core';
import { nativeModule, eventEmitter } from './RcloneNativeModule';
import type {
  RcloneConfig,
  RemoteSpec,
  SyncOptions,
  QuotaInfo,
  AuthorizeResult,
  RcloneProgressEvent,
  RcloneJobEvent,
} from './RcloneTypes';

export type { EventSubscription };

async function rpc<T = unknown>(
  method: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  const raw = await nativeModule.rpcCall(method, JSON.stringify(params));
  return JSON.parse(raw) as T;
}

export class RcloneService {
  // -------------------------------------------------------------------------
  // Config
  // -------------------------------------------------------------------------

  async getConfig(): Promise<RcloneConfig> {
    return rpc<RcloneConfig>('config/dump');
  }

  async addRemote(spec: RemoteSpec): Promise<void> {
    await rpc('config/create', {
      name: spec.name,
      type: spec.provider,
      parameters: spec.options ?? {},
      obscure: true,
    });
  }

  async deleteRemote(name: string): Promise<void> {
    await rpc('config/delete', { name });
  }

  async createUnionRemote(names: string[]): Promise<string> {
    const unionName = `union_${Date.now()}`;
    await rpc('config/create', {
      name: unionName,
      type: 'union',
      parameters: { upstreams: names.join(' ') },
    });
    return unionName;
  }

  async createCryptRemote(baseName: string, password: string): Promise<string> {
    const cryptName = `${baseName}_crypt`;
    await rpc('config/create', {
      name: cryptName,
      type: 'crypt',
      parameters: { remote: `${baseName}:`, password },
      obscure: true,
    });
    return cryptName;
  }

  // -------------------------------------------------------------------------
  // Sync
  // -------------------------------------------------------------------------

  async sync(
    sourceDir: string,
    targetRemote: string,
    options?: SyncOptions,
  ): Promise<string> {
    const params: Record<string, unknown> = {
      srcFs: sourceDir,
      dstFs: targetRemote,
      _async: true,
    };
    if (options?.transfers !== undefined) params['transfers'] = options.transfers;
    if (options?.checkers !== undefined) params['checkers'] = options.checkers;
    if (options?.bwlimit !== undefined) params['bwlimit'] = options.bwlimit;
    if (options?.retries !== undefined) params['retries'] = options.retries;
    if (options?.dryRun) params['dryRun'] = true;
    const result = await rpc<{ jobid: number }>('sync/sync', params);
    return String(result.jobid);
  }

  // -------------------------------------------------------------------------
  // Storage
  // -------------------------------------------------------------------------

  async about(remoteName: string): Promise<QuotaInfo> {
    const r = await rpc<{ total?: number; used?: number; free?: number }>(
      'operations/about',
      { fs: `${remoteName}:` },
    );
    return { totalBytes: r.total ?? 0, usedBytes: r.used ?? 0, freeBytes: r.free ?? 0 };
  }

  async deleteRemotePath(remoteName: string, path: string): Promise<void> {
    await rpc('operations/purge', { fs: `${remoteName}:`, remote: path });
  }

  // -------------------------------------------------------------------------
  // OAuth
  // -------------------------------------------------------------------------

  async startOAuthFlow(provider: string): Promise<string> {
    return nativeModule.startOAuthFlow(provider);
  }

  async exchangeOAuthCode(provider: string, code: string): Promise<AuthorizeResult> {
    const raw = await nativeModule.exchangeOAuthCode(provider, code);
    return JSON.parse(raw) as AuthorizeResult;
  }

  // -------------------------------------------------------------------------
  // Event subscriptions
  // -------------------------------------------------------------------------

  subscribeToProgress(cb: (event: RcloneProgressEvent) => void): EventSubscription {
    return eventEmitter.addListener('onProgress', cb);
  }

  subscribeToJobStatus(cb: (event: RcloneJobEvent) => void): EventSubscription {
    return eventEmitter.addListener('onJobStatusChange', cb);
  }

  subscribeToAuthCallback(
    cb: (event: { provider: string; url: string }) => void,
  ): EventSubscription {
    return eventEmitter.addListener('onAuthCallback', cb);
  }
}
