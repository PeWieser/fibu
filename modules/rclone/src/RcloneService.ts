/**
 * Typed service that translates high-level operations into rclone RC calls.
 * Native initialization is shared by all calls on a service instance so that
 * concurrent requests cannot race the rclone engine startup.
 */

import type { EventSubscription } from 'expo-modules-core';
import { nativeModule, eventEmitter } from './RcloneNativeModule';
import type { NativeRcloneModule } from './RcloneNativeModule';
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

function remoteRoot(remoteName: string): string {
  return remoteName.endsWith(':') ? remoteName : `${remoteName}:`;
}

export class RcloneService {
  private initialization: Promise<void> | null = null;

  constructor(private readonly module: NativeRcloneModule = nativeModule) {}

  private async ensureInitialized(): Promise<void> {
    if (this.initialization === null) {
      this.initialization = this.module.initialize().catch((error: unknown) => {
        this.initialization = null;
        throw error;
      });
    }
    await this.initialization;
  }

  private async rpc<T = unknown>(method: string, params: Record<string, unknown> = {}): Promise<T> {
    await this.ensureInitialized();
    const raw = await this.module.rpcCall(method, JSON.stringify(params));
    return JSON.parse(raw) as T;
  }

  async getConfig(): Promise<RcloneConfig> {
    return this.rpc<RcloneConfig>('config/dump');
  }

  async addRemote(spec: RemoteSpec): Promise<void> {
    await this.rpc('config/create', {
      name: spec.name,
      type: spec.provider,
      parameters: spec.options ?? {},
      obscure: true,
    });
  }

  async deleteRemote(name: string): Promise<void> {
    await this.rpc('config/delete', { name });
  }

  async createUnionRemote(names: string[]): Promise<string> {
    const unionName = `union_${Date.now()}`;
    await this.rpc('config/create', {
      name: unionName,
      type: 'union',
      parameters: { upstreams: names.join(' ') },
    });
    return unionName;
  }

  async createCryptRemote(baseName: string, password: string): Promise<string> {
    const normalizedBaseName = baseName.replace(/:+$/, '');
    const cryptName = `${normalizedBaseName}_crypt`;
    await this.rpc('config/create', {
      name: cryptName,
      type: 'crypt',
      parameters: { remote: remoteRoot(normalizedBaseName), password },
      obscure: true,
    });
    return cryptName;
  }

  async sync(sourceDir: string, targetRemote: string, options?: SyncOptions): Promise<string> {
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
    const result = await this.rpc<{ jobid: number }>('sync/sync', params);
    return String(result.jobid);
  }

  async about(remoteName: string): Promise<QuotaInfo> {
    const result = await this.rpc<{ total?: number; used?: number; free?: number }>(
      'operations/about',
      { fs: remoteRoot(remoteName) },
    );
    return {
      totalBytes: result.total ?? 0,
      usedBytes: result.used ?? 0,
      freeBytes: result.free ?? 0,
    };
  }

  async deleteRemotePath(remoteName: string, path: string): Promise<void> {
    await this.rpc('operations/purge', {
      fs: remoteRoot(remoteName),
      remote: path,
    });
  }

  async startOAuthFlow(provider: string): Promise<string> {
    await this.ensureInitialized();
    return this.module.startOAuthFlow(provider);
  }

  async exchangeOAuthCode(provider: string, code: string): Promise<AuthorizeResult> {
    await this.ensureInitialized();
    const raw = await this.module.exchangeOAuthCode(provider, code);
    return JSON.parse(raw) as AuthorizeResult;
  }

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
