/** Unit tests for the typed rclone RC adapter. */

jest.mock('expo-modules-core', () => {
  class MockEventEmitter {
    addListener = jest.fn(() => ({ remove: jest.fn() }));
  }

  return {
    __esModule: true,
    requireNativeModule: jest.fn(() => ({
      initialize: jest.fn(),
      rpcCall: jest.fn(),
      startOAuthFlow: jest.fn(),
      exchangeOAuthCode: jest.fn(),
    })),
    EventEmitter: MockEventEmitter,
  };
});

import { RcloneService } from '../../../modules/rclone/src/RcloneService';
import { eventEmitter, nativeModule } from '../../../modules/rclone/src/RcloneNativeModule';
import type { NativeRcloneModule } from '../../../modules/rclone/src/RcloneNativeModule';

const mockedNativeModule = nativeModule as jest.Mocked<NativeRcloneModule>;

function rpcParams(callIndex = 0): Record<string, unknown> {
  const serialized = mockedNativeModule.rpcCall.mock.calls[callIndex]?.[1];
  if (serialized === undefined) {
    throw new Error(`Missing rpcCall at index ${callIndex}`);
  }
  return JSON.parse(serialized) as Record<string, unknown>;
}

describe('RcloneService', () => {
  let service: RcloneService;

  beforeEach(() => {
    jest.clearAllMocks();
    mockedNativeModule.initialize.mockResolvedValue(undefined);
    mockedNativeModule.rpcCall.mockResolvedValue('{}');
    mockedNativeModule.startOAuthFlow.mockResolvedValue('https://auth.example.test');
    mockedNativeModule.exchangeOAuthCode.mockResolvedValue(
      JSON.stringify({ provider: 'drive', configName: 'photos', token: 'encrypted' }),
    );
    service = new RcloneService();
  });

  describe('native lifecycle', () => {
    it('initializes the native engine once before concurrent RPC calls', async () => {
      mockedNativeModule.rpcCall.mockResolvedValue('{}');

      await Promise.all([service.getConfig(), service.deleteRemote('archive')]);

      expect(mockedNativeModule.initialize).toHaveBeenCalledTimes(1);
      expect(mockedNativeModule.rpcCall).toHaveBeenCalledTimes(2);
    });

    it('retries initialization after a rejected attempt', async () => {
      mockedNativeModule.initialize
        .mockRejectedValueOnce(new Error('startup failed'))
        .mockResolvedValueOnce(undefined);

      await expect(service.getConfig()).rejects.toThrow('startup failed');
      await expect(service.getConfig()).resolves.toEqual({});

      expect(mockedNativeModule.initialize).toHaveBeenCalledTimes(2);
    });
  });

  describe('configuration RPCs', () => {
    it('loads and parses the rclone config', async () => {
      const config = { photos: { type: 'drive' } };
      mockedNativeModule.rpcCall.mockResolvedValue(JSON.stringify(config));

      await expect(service.getConfig()).resolves.toEqual(config);
      expect(mockedNativeModule.rpcCall).toHaveBeenCalledWith('config/dump', '{}');
    });

    it('creates a remote with obscured credentials', async () => {
      await service.addRemote({
        name: 'photos',
        provider: 'drive',
        options: { token: 'secret-token' },
      });

      expect(mockedNativeModule.rpcCall).toHaveBeenCalledWith('config/create', expect.any(String));
      expect(rpcParams()).toEqual({
        name: 'photos',
        type: 'drive',
        parameters: { token: 'secret-token' },
        obscure: true,
      });
    });

    it('deletes a remote', async () => {
      await service.deleteRemote('photos');

      expect(mockedNativeModule.rpcCall).toHaveBeenCalledWith(
        'config/delete',
        JSON.stringify({ name: 'photos' }),
      );
    });

    it('creates and returns a deterministic union name', async () => {
      jest.spyOn(Date, 'now').mockReturnValue(1234);

      await expect(service.createUnionRemote(['a:', 'b:'])).resolves.toBe('union_1234');
      expect(rpcParams()).toEqual({
        name: 'union_1234',
        type: 'union',
        parameters: { upstreams: 'a: b:' },
      });
    });

    it('creates a crypt remote without duplicating the remote separator', async () => {
      await expect(service.createCryptRemote('photos:', 'password')).resolves.toBe('photos_crypt');
      expect(rpcParams()).toEqual({
        name: 'photos_crypt',
        type: 'crypt',
        parameters: { remote: 'photos:', password: 'password' },
        obscure: true,
      });
    });
  });

  describe('sync and storage RPCs', () => {
    it('starts an asynchronous sync and returns its job id', async () => {
      mockedNativeModule.rpcCall.mockResolvedValue(JSON.stringify({ jobid: 42 }));

      await expect(
        service.sync('/local/photos', 'drive:backup', {
          transfers: 4,
          checkers: 2,
          bwlimit: '10M',
          retries: 3,
          dryRun: true,
        }),
      ).resolves.toBe('42');
      expect(mockedNativeModule.rpcCall).toHaveBeenCalledWith('sync/sync', expect.any(String));
      expect(rpcParams()).toEqual({
        srcFs: '/local/photos',
        dstFs: 'drive:backup',
        _async: true,
        transfers: 4,
        checkers: 2,
        bwlimit: '10M',
        retries: 3,
        dryRun: true,
      });
    });

    it('maps missing quota values to zero', async () => {
      mockedNativeModule.rpcCall.mockResolvedValue(JSON.stringify({ total: 100, used: 40 }));

      await expect(service.about('drive:')).resolves.toEqual({
        totalBytes: 100,
        usedBytes: 40,
        freeBytes: 0,
      });
      expect(rpcParams()).toEqual({ fs: 'drive:' });
    });

    it('purges a path from a normalized remote root', async () => {
      await service.deleteRemotePath('drive', '/backup/photo.jpg');

      expect(mockedNativeModule.rpcCall).toHaveBeenCalledWith(
        'operations/purge',
        expect.any(String),
      );
      expect(rpcParams()).toEqual({ fs: 'drive:', remote: '/backup/photo.jpg' });
    });
  });

  describe('OAuth bridge', () => {
    it('initializes and starts the provider flow', async () => {
      await expect(service.startOAuthFlow('drive')).resolves.toBe('https://auth.example.test');
      expect(mockedNativeModule.initialize).toHaveBeenCalledTimes(1);
      expect(mockedNativeModule.startOAuthFlow).toHaveBeenCalledWith('drive');
    });

    it('parses the authorization-code exchange result', async () => {
      await expect(service.exchangeOAuthCode('drive', 'code-123')).resolves.toEqual({
        provider: 'drive',
        configName: 'photos',
        token: 'encrypted',
      });
      expect(mockedNativeModule.exchangeOAuthCode).toHaveBeenCalledWith('drive', 'code-123');
    });
  });

  describe('event subscriptions', () => {
    it.each([
      ['subscribeToProgress', 'onProgress'],
      ['subscribeToJobStatus', 'onJobStatusChange'],
      ['subscribeToAuthCallback', 'onAuthCallback'],
    ] as const)('%s registers %s and returns a removable subscription', (method, eventName) => {
      const callback = jest.fn();
      const subscription = service[method](callback);

      expect(eventEmitter.addListener).toHaveBeenCalledWith(eventName, callback);
      expect(subscription).toHaveProperty('remove');
      expect(() => subscription.remove()).not.toThrow();
    });
  });
});
