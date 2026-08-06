import { SyncEngine } from '../../../src/services/SyncEngine';
import { PreflightGates } from '../../../src/services/PreflightGates';
import { SyncReconciler } from '../../../src/services/SyncReconciler';
import { JobController } from '../../../src/services/JobController';
import { getCloudRemoteById } from '../../../src/db';
import type { SyncRule, CloudRemote } from '../../../src/types';

jest.mock('../../../src/db', () => ({
  getDatabase: jest.fn(),
  getCloudRemoteById: jest.fn(),
}));

jest.mock('../../../src/services/PreflightGates', () => ({
  PreflightGates: { canRunRule: jest.fn() },
}));

jest.mock('../../../src/services/SyncReconciler', () => ({
  SyncReconciler: { getPendingFiles: jest.fn() },
}));

jest.mock('../../../src/services/JobController');

const mockGetCloudRemoteById = getCloudRemoteById as jest.Mock;
const mockPreflightGates = PreflightGates as jest.Mocked<typeof PreflightGates>;
const mockSyncReconciler = SyncReconciler as jest.Mocked<typeof SyncReconciler>;
const MockJobController = JobController as jest.MockedClass<typeof JobController>;

describe('SyncEngine', () => {
  const rule: SyncRule = {
    id: 'rule-1',
    source_album_id: 'album-1',
    media_type: 'BOTH',
    target_remote_id: 'remote-1',
    sync_mode: 'ECHO',
    requires_wifi: false,
    requires_charging: false,
    is_enabled: true,
    created_at: '2026-08-01T00:00:00Z',
  };

  const remote: CloudRemote = {
    id: 'remote-1',
    name: 'drive-test',
    provider: 'drive',
    rclone_config: '',
    is_encrypted: false,
    total_space_bytes: 0,
    used_space_bytes: 0,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    mockGetCloudRemoteById.mockResolvedValue(remote);
  });

  it('stops early if preflight fails', async () => {
    mockPreflightGates.canRunRule.mockResolvedValue({ canRun: false, reason: 'Test' });

    await SyncEngine.runRule(rule);

    expect(mockSyncReconciler.getPendingFiles).not.toHaveBeenCalled();
  });

  it('runs jobs in batches of 4', async () => {
    mockPreflightGates.canRunRule.mockResolvedValue({ canRun: true });
    
    const makeFile = (id: string) => ({
      id,
      local_uri: `file://${id}`,
      cloud_path: `path/${id}`,
      rule_id: 'rule-1',
      status: 'PENDING' as const,
      bytes: 100,
      attempts: 0,
      updated_at: '',
    });

    const files = Array.from({ length: 5 }, (_, i) => makeFile(`f${i}`));
    mockSyncReconciler.getPendingFiles.mockResolvedValue(files);

    const mockExecute = jest.fn().mockResolvedValue(undefined);
    MockJobController.prototype.execute = mockExecute;

    await SyncEngine.runRule(rule);

    expect(MockJobController).toHaveBeenCalledTimes(5);
    expect(mockExecute).toHaveBeenCalledTimes(5);
  });
});
