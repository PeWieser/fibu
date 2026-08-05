/**
 * rcloneService.test.ts — Unit tests for RcloneService.
 *
 * expo-modules-core is mocked so that requireNativeModule / EventEmitter never
 * touch native infrastructure in the Jest (Node.js) environment.
 */

// ---------------------------------------------------------------------------
// Mock expo-modules-core BEFORE any module under test is imported.
// ---------------------------------------------------------------------------

/** Minimal mock subscription returned by the mock EventEmitter. */
const mockSubscription = { remove: jest.fn() };

/** Captured listeners so we can assert they are registered. */
const mockAddListener = jest.fn(() => mockSubscription);

class MockEventEmitter {
  addListener = mockAddListener;
}

const mockNativeModule = {
  initialize: jest.fn(),
  rpcCall: jest.fn(),
  startOAuthFlow: jest.fn(),
  exchangeOAuthCode: jest.fn(),
};

jest.mock('expo-modules-core', () => ({
  requireNativeModule: jest.fn(() => mockNativeModule),
  EventEmitter: MockEventEmitter,
}));

// ---------------------------------------------------------------------------
// Import AFTER mocks are in place.
// ---------------------------------------------------------------------------

import { RcloneService } from '../../../modules/rclone/src/RcloneService';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Assert that a given async function rejects with an Error whose message
 * matches the NotImplemented pattern for RcloneService.
 */
async function expectNotImplemented(
  fn: () => Promise<unknown>,
  methodName: string,
): Promise<void> {
  await expect(fn()).rejects.toThrow(
    new Error(`NotImplemented: RcloneService.${methodName}`),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('RcloneService', () => {
  let svc: RcloneService;

  beforeEach(() => {
    svc = new RcloneService();
    jest.clearAllMocks();
  });

  // -------------------------------------------------------------------------
  // NotImplemented stubs
  // -------------------------------------------------------------------------

  describe('NotImplemented stubs', () => {
    it('getConfig throws NotImplemented', async () => {
      await expectNotImplemented(() => svc.getConfig(), 'getConfig');
    });

    it('addRemote throws NotImplemented', async () => {
      await expectNotImplemented(
        () => svc.addRemote({ name: 'test', provider: 'drive' }),
        'addRemote',
      );
    });

    it('deleteRemote throws NotImplemented', async () => {
      await expectNotImplemented(() => svc.deleteRemote('test'), 'deleteRemote');
    });

    it('createUnionRemote throws NotImplemented', async () => {
      await expectNotImplemented(
        () => svc.createUnionRemote(['remote1', 'remote2']),
        'createUnionRemote',
      );
    });

    it('createCryptRemote throws NotImplemented', async () => {
      await expectNotImplemented(
        () => svc.createCryptRemote('base', 'secret'),
        'createCryptRemote',
      );
    });

    it('sync throws NotImplemented (not a silent no-op)', async () => {
      await expectNotImplemented(
        () => svc.sync('/local/photos', 'drive:EchoVault'),
        'sync',
      );
    });

    it('sync throws NotImplemented even when options are provided', async () => {
      await expectNotImplemented(
        () =>
          svc.sync('/local/photos', 'drive:EchoVault', {
            transfers: 4,
            dryRun: true,
          }),
        'sync',
      );
    });

    it('about throws NotImplemented', async () => {
      await expectNotImplemented(() => svc.about('drive:'), 'about');
    });

    it('deleteRemotePath throws NotImplemented', async () => {
      await expectNotImplemented(
        () => svc.deleteRemotePath('drive:', '/EchoVault/img.jpg'),
        'deleteRemotePath',
      );
    });

    it('startOAuthFlow throws NotImplemented', async () => {
      await expectNotImplemented(() => svc.startOAuthFlow('drive'), 'startOAuthFlow');
    });

    it('exchangeOAuthCode throws NotImplemented', async () => {
      await expectNotImplemented(
        () => svc.exchangeOAuthCode('drive', 'auth-code-123'),
        'exchangeOAuthCode',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Error shape
  // -------------------------------------------------------------------------

  describe('Error shape', () => {
    it('every method rejects with an Error instance (not a string)', async () => {
      const rejection = await svc.getConfig().catch((e: unknown) => e);
      expect(rejection).toBeInstanceOf(Error);
    });

    it('error message matches /^NotImplemented: RcloneService\\./', async () => {
      const rejection = await svc.getConfig().catch((e: unknown) => e);
      expect(rejection).toBeInstanceOf(Error);
      expect((rejection as Error).message).toMatch(
        /^NotImplemented: RcloneService\./,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Event subscription helpers
  // -------------------------------------------------------------------------

  describe('Event subscription helpers', () => {
    it('subscribeToProgress returns an object with a remove() method', () => {
      const sub = svc.subscribeToProgress(() => undefined);
      expect(sub).toHaveProperty('remove');
      expect(typeof sub.remove).toBe('function');
    });

    it('subscribeToJobStatus returns an object with a remove() method', () => {
      const sub = svc.subscribeToJobStatus(() => undefined);
      expect(sub).toHaveProperty('remove');
      expect(typeof sub.remove).toBe('function');
    });

    it('subscribeToAuthCallback returns an object with a remove() method', () => {
      const sub = svc.subscribeToAuthCallback(() => undefined);
      expect(sub).toHaveProperty('remove');
      expect(typeof sub.remove).toBe('function');
    });

    it('calling remove() on the returned subscription does not throw', () => {
      const sub = svc.subscribeToProgress(() => undefined);
      expect(() => sub.remove()).not.toThrow();
    });

    it('subscribeToProgress registers listener via addListener("onProgress")', () => {
      const cb = jest.fn();
      svc.subscribeToProgress(cb);
      expect(mockAddListener).toHaveBeenCalledWith('onProgress', cb);
    });

    it('subscribeToJobStatus registers listener via addListener("onJobStatusChange")', () => {
      const cb = jest.fn();
      svc.subscribeToJobStatus(cb);
      expect(mockAddListener).toHaveBeenCalledWith('onJobStatusChange', cb);
    });

    it('subscribeToAuthCallback registers listener via addListener("onAuthCallback")', () => {
      const cb = jest.fn();
      svc.subscribeToAuthCallback(cb);
      expect(mockAddListener).toHaveBeenCalledWith('onAuthCallback', cb);
    });
  });
});
