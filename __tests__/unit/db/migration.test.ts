import { createTestDb } from '../../helpers/testDb';
import { runMigrations } from '../../../src/db/migrations';

describe('Database Migration Runner', () => {
  it('should run v001 migration on a fresh database and set user_version to 1', async () => {
    const db = createTestDb();

    // Verify initial user_version is 0
    const initialVersion = await db.getFirstAsync<{ user_version: number }>(
      'PRAGMA user_version;'
    );
    expect(initialVersion?.user_version).toBe(0);

    // Execute migrations
    const newVersion = await runMigrations(db);
    expect(newVersion).toBe(1);

    // Verify updated user_version is 1
    const updatedVersion = await db.getFirstAsync<{ user_version: number }>(
      'PRAGMA user_version;'
    );
    expect(updatedVersion?.user_version).toBe(1);
  });

  it('should create CloudRemotes, SyncRules, and FileState tables and required indices', async () => {
    const db = createTestDb();
    await runMigrations(db);

    // Verify tables exist in sqlite_master
    const tables = await db.getAllAsync<{ name: string }>(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    );
    const tableNames = tables.map((t) => t.name);

    expect(tableNames).toContain('CloudRemotes');
    expect(tableNames).toContain('SyncRules');
    expect(tableNames).toContain('FileState');

    // Verify indices exist in sqlite_master
    const indices = await db.getAllAsync<{ name: string }>(
      "SELECT name FROM sqlite_master WHERE type='index';"
    );
    const indexNames = indices.map((i) => i.name);

    expect(indexNames).toContain('idx_file_state_rule_status');
    expect(indexNames).toContain('idx_file_state_rule_local_uri');
  });

  it('should be idempotent when executed multiple times', async () => {
    const db = createTestDb();

    // Run first time
    const version1 = await runMigrations(db);
    expect(version1).toBe(1);

    // Run second time
    const version2 = await runMigrations(db);
    expect(version2).toBe(1);

    // Verify user_version remains 1
    const currentVersion = await db.getFirstAsync<{ user_version: number }>(
      'PRAGMA user_version;'
    );
    expect(currentVersion?.user_version).toBe(1);
  });
});
