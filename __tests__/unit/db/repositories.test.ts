import { createTestDb } from '../../helpers/testDb';
import { runMigrations } from '../../../src/db/migrations';

const mockStore = new Map<string, string>();
jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(async (key: string) => mockStore.get(key) ?? null),
  setItemAsync: jest.fn(async (key: string, val: string) => {
    mockStore.set(key, val);
  }),
  deleteItemAsync: jest.fn(async (key: string) => {
    mockStore.delete(key);
  }),
}));

jest.mock('expo-crypto', () => ({
  getRandomBytesAsync: jest.fn(async (byteCount: number) => {
    return new Uint8Array(byteCount).fill(1);
  }),
}));

import {
  createCloudRemote,
  getCloudRemoteById,
  getAllCloudRemotes,
  updateCloudRemote,
  updateSpaceUsage,
  deleteCloudRemote,
  createSyncRule,
  getSyncRuleById,
  getAllSyncRules,
  getSyncRulesByRemoteId,
  updateSyncRule,
  toggleSyncRuleEnabled,
  deleteSyncRule,
  createFileState,
  getFileStateById,
  getFileStateByRuleAndUri,
  getFileStatesByStatus,
  getAllFileStates,
  updateFileStatus,
  upsertFileState,
} from '../../../src/db/repositories';
import { seedDatabase } from '../../../src/db/seed';

describe('Database Repositories & Seed Helper', () => {
  let db: ReturnType<typeof createTestDb>;

  beforeEach(async () => {
    db = createTestDb();
    await runMigrations(db);
  });

  describe('CloudRemoteRepo', () => {
    it('should create and retrieve a CloudRemote with encrypted config at rest', async () => {
      const created = await createCloudRemote(db, {
        id: 'remote-test-1',
        name: 'Test Drive',
        provider: 'drive',
        rclone_config: '[drive]\ntype = drive\nsecret_key = my_secret',
        is_encrypted: false,
        total_space_bytes: 1000,
        used_space_bytes: 500,
      });

      expect(created.id).toBe('remote-test-1');
      expect(created.name).toBe('Test Drive');

      // Verify repo returns decrypted rclone_config
      const fetched = await getCloudRemoteById(db, 'remote-test-1');
      expect(fetched).not.toBeNull();
      expect(fetched?.rclone_config).toBe('[drive]\ntype = drive\nsecret_key = my_secret');

      // Verify raw database stores encrypted rclone_config (not plaintext)
      const rawRow = await db.getFirstAsync<{ rclone_config: string }>(
        'SELECT rclone_config FROM CloudRemotes WHERE id = ?',
        'remote-test-1'
      );
      expect(rawRow?.rclone_config).not.toBe('[drive]\ntype = drive\nsecret_key = my_secret');
      expect(typeof rawRow?.rclone_config).toBe('string');
      expect(rawRow?.rclone_config.length).toBeGreaterThan(0);
    });

    it('should update and delete CloudRemote', async () => {
      await createCloudRemote(db, {
        id: 'remote-test-2',
        name: 'Initial Name',
        provider: 'dropbox',
        rclone_config: 'config_data',
        is_encrypted: true,
        total_space_bytes: 2000,
        used_space_bytes: 1000,
      });

      const existing = await getCloudRemoteById(db, 'remote-test-2');
      expect(existing).not.toBeNull();
      if (!existing) return;

      await updateCloudRemote(db, {
        ...existing,
        name: 'Updated Name',
        used_space_bytes: 1500,
      });

      const updated = await getCloudRemoteById(db, 'remote-test-2');
      expect(updated?.name).toBe('Updated Name');
      expect(updated?.used_space_bytes).toBe(1500);

      await updateSpaceUsage(db, 'remote-test-2', 1800, 2000);
      const afterSpaceUpdate = await getCloudRemoteById(db, 'remote-test-2');
      expect(afterSpaceUpdate?.used_space_bytes).toBe(1800);
      expect(afterSpaceUpdate?.last_probed_at).toBeDefined();

      const deleted = await deleteCloudRemote(db, 'remote-test-2');
      expect(deleted).toBe(true);

      const afterDelete = await getCloudRemoteById(db, 'remote-test-2');
      expect(afterDelete).toBeNull();
    });
  });

  describe('SyncRuleRepo', () => {
    it('should CRUD sync rules', async () => {
      await createCloudRemote(db, {
        id: 'remote-for-rule',
        name: 'Remote For Rule',
        provider: 'mega',
        rclone_config: 'cfg',
        is_encrypted: false,
        total_space_bytes: 10000,
        used_space_bytes: 0,
      });

      const rule = await createSyncRule(db, {
        id: 'rule-test-1',
        source_album_id: 'album-1',
        media_type: 'PHOTOS',
        target_remote_id: 'remote-for-rule',
        sync_mode: 'ECHO',
        requires_wifi: true,
        requires_charging: false,
        is_enabled: true,
      });

      expect(rule.id).toBe('rule-test-1');

      const fetched = await getSyncRuleById(db, 'rule-test-1');
      expect(fetched?.source_album_id).toBe('album-1');
      expect(fetched?.requires_wifi).toBe(true);

      const rulesForRemote = await getSyncRulesByRemoteId(db, 'remote-for-rule');
      expect(rulesForRemote.length).toBe(1);

      await toggleSyncRuleEnabled(db, 'rule-test-1', false);
      const disabledRule = await getSyncRuleById(db, 'rule-test-1');
      expect(disabledRule?.is_enabled).toBe(false);

      await updateSyncRule(db, {
        ...rule,
        is_enabled: true,
        sync_mode: 'ARCHIVE',
      });
      const updatedRule = await getSyncRuleById(db, 'rule-test-1');
      expect(updatedRule?.sync_mode).toBe('ARCHIVE');

      const deleted = await deleteSyncRule(db, 'rule-test-1');
      expect(deleted).toBe(true);
    });
  });

  describe('FileStateRepo', () => {
    beforeEach(async () => {
      await createCloudRemote(db, {
        id: 'remote-file-test',
        name: 'Remote File Test',
        provider: 'drive',
        rclone_config: 'cfg',
        is_encrypted: false,
        total_space_bytes: 10000,
        used_space_bytes: 0,
      });
      await createSyncRule(db, {
        id: 'rule-file-test',
        source_album_id: 'album-file-test',
        media_type: 'BOTH',
        target_remote_id: 'remote-file-test',
        sync_mode: 'ECHO',
        requires_wifi: false,
        requires_charging: false,
        is_enabled: true,
      });
    });

    it('should create, query, update, and upsert FileState', async () => {
      const file1 = await createFileState(db, {
        id: 'file-1',
        local_uri: 'file:///path/to/img1.jpg',
        cloud_path: 'EchoVault/img1.jpg',
        rule_id: 'rule-file-test',
        status: 'PENDING',
        bytes: 1024,
        attempts: 0,
      });

      expect(file1.id).toBe('file-1');

      const fetchedByUri = await getFileStateByRuleAndUri(
        db,
        'rule-file-test',
        'file:///path/to/img1.jpg'
      );
      expect(fetchedByUri?.id).toBe('file-1');

      await updateFileStatus(db, 'file-1', 'FAILED', 'Network error', true);
      const failedFile = await getFileStateById(db, 'file-1');
      expect(failedFile?.status).toBe('FAILED');
      expect(failedFile?.last_error).toBe('Network error');
      expect(failedFile?.attempts).toBe(1);

      const failedFiles = await getFileStatesByStatus(db, 'rule-file-test', 'FAILED');
      expect(failedFiles.length).toBe(1);

      // Test upsert on existing rule_id + local_uri
      const upserted = await upsertFileState(db, {
        local_uri: 'file:///path/to/img1.jpg',
        cloud_path: 'EchoVault/img1_updated.jpg',
        rule_id: 'rule-file-test',
        status: 'SYNCED',
        bytes: 2048,
        attempts: 2,
      });

      expect(upserted.id).toBe('file-1');

      const afterUpsert = await getFileStateById(db, 'file-1');
      expect(afterUpsert?.status).toBe('SYNCED');
      expect(afterUpsert?.bytes).toBe(2048);
      expect(afterUpsert?.cloud_path).toBe('EchoVault/img1_updated.jpg');
    });
  });

  describe('seedDatabase Helper', () => {
    it('should seed 3 remotes, 4 rules, and 100 file states', async () => {
      await seedDatabase(db);

      const remotes = await getAllCloudRemotes(db);
      expect(remotes.length).toBe(3);

      const rules = await getAllSyncRules(db);
      expect(rules.length).toBe(4);

      const fileStates = await getAllFileStates(db);
      expect(fileStates.length).toBe(100);
    });
  });
});
