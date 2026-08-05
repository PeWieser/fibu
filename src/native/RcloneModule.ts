import { CloudRemote } from '../types';

export interface RemoteSpec {
  name: string;
  provider: CloudRemote['provider'];
  options?: Record<string, string>;
}

export interface SyncOptions {
  transfers?: number;
  checkers?: number;
  bwlimit?: string;
  retries?: number;
}

export interface QuotaInfo {
  totalBytes: number;
  usedBytes: number;
  freeBytes: number;
}

/**
 * Typed bridge for librclone RPC calls via Expo Native Modules.
 * Throwing NotImplemented until Phase 3b native bindings land.
 */
export class RcloneBridge {
  /** Map to rc/config/dump */
  async getConfig(): Promise<string> {
    throw new Error('NotImplemented: RcloneBridge.getConfig');
  }

  /** Map to config/create */
  async addRemote(_spec: RemoteSpec): Promise<void> {
    throw new Error('NotImplemented: RcloneBridge.addRemote');
  }

  /** Map to config/delete */
  async deleteRemote(_name: string): Promise<void> {
    throw new Error('NotImplemented: RcloneBridge.deleteRemote');
  }

  /** Map to config/create (union remote) */
  async createUnionRemote(_remoteIds: string[]): Promise<string> {
    throw new Error('NotImplemented: RcloneBridge.createUnionRemote');
  }

  /** Map to config/create (crypt remote) */
  async createCryptRemote(_baseRemoteId: string, _password: string): Promise<string> {
    throw new Error('NotImplemented: RcloneBridge.createCryptRemote');
  }

  /** Map to sync/sync */
  async sync(_sourceDir: string, _targetRemote: string, _options?: SyncOptions): Promise<void> {
    throw new Error('NotImplemented: RcloneBridge.sync');
  }

  /** Map to operations/about */
  async about(_remoteName: string): Promise<QuotaInfo> {
    throw new Error('NotImplemented: RcloneBridge.about');
  }

  /** Map to operations/purge or operations/deletefile */
  async deleteRemotePath(_remoteName: string, _path: string): Promise<void> {
    throw new Error('NotImplemented: RcloneBridge.deleteRemotePath');
  }

  /** Map to config/authorize */
  async authorize(_provider: CloudRemote['provider']): Promise<void> {
    throw new Error('NotImplemented: RcloneBridge.authorize');
  }
}

export const RcloneModule = new RcloneBridge();
