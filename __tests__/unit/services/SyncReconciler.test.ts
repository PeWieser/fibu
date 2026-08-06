import { SyncReconciler } from '../../../src/services/SyncReconciler';
import { getDatabase, getFileStatesByStatus } from '../../../src/db';
import type { SyncRule, FileState } from '../../../src/types';

jest.mock('../../../src/db', () => ({
  getDatabase: jest.fn(),
  getFileStatesByStatus: jest.fn(),
}));

const mockGetDatabase = getDatabase as jest.Mock;
const mockGetFileStatesByStatus = getFileStatesByStatus as jest.Mock;

describe('SyncReconciler', () => {
  const ruleEcho: SyncRule = {
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

  const ruleArchive: SyncRule = {
    ...ruleEcho,
    sync_mode: 'ARCHIVE',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    mockGetDatabase.mockResolvedValue({});
  });

  const makeFile = (id: string, attempts: number, date: string): FileState => ({
    id,
    local_uri: `file://${id}`,
    cloud_path: `path/${id}`,
    rule_id: 'rule-1',
    status: 'PENDING',
    bytes: 100,
    attempts,
    updated_at: date,
  });

  it('gets PENDING and FAILED files, sorting by attempts then date', async () => {
    const f1 = makeFile('f1', 2, '2026-08-01T10:00:00Z');
    const f2 = makeFile('f2', 0, '2026-08-01T11:00:00Z');
    const f3 = makeFile('f3', 0, '2026-08-01T12:00:00Z');

    mockGetFileStatesByStatus.mockImplementation(async (_db, _ruleId, status) => {
      if (status === 'PENDING') return [f1, f3];
      if (status === 'FAILED') return [f2];
      return [];
    });

    const files = await SyncReconciler.getPendingFiles(ruleArchive);
    
    // Sort logic: 
    // attempts asc: f2(0), f3(0) before f1(2)
    // updated_at desc (newer first): f3(12:00) before f2(11:00)
    // Result: f3, f2, f1
    expect(files.map(f => f.id)).toEqual(['f3', 'f2', 'f1']);
  });

  it('includes DELETED_LOCALLY files only in ECHO mode', async () => {
    const f1 = makeFile('f1', 0, '2026-08-01T10:00:00Z');
    const fDeleted = makeFile('fDeleted', 0, '2026-08-01T11:00:00Z');
    fDeleted.status = 'DELETED_LOCALLY';

    mockGetFileStatesByStatus.mockImplementation(async (_db, _ruleId, status) => {
      if (status === 'PENDING') return [f1];
      if (status === 'DELETED_LOCALLY') return [fDeleted];
      return [];
    });

    const filesEcho = await SyncReconciler.getPendingFiles(ruleEcho);
    expect(filesEcho.map(f => f.id)).toContain('fDeleted');

    const filesArchive = await SyncReconciler.getPendingFiles(ruleArchive);
    expect(filesArchive.map(f => f.id)).not.toContain('fDeleted');
  });
});
