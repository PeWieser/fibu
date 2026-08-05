import type { DBConnection, Migration } from '../types';
import { v001Migration } from './v001';

export const migrations: Migration[] = [v001Migration];

/**
 * Runs versioned and idempotent migrations using SQLite PRAGMA user_version.
 * Returns the final user_version of the database.
 */
export async function runMigrations(db: DBConnection): Promise<number> {
  let currentVersion = 0;
  const result = await db.getFirstAsync<{ user_version: number }>(
    'PRAGMA user_version;'
  );

  if (result && typeof result.user_version === 'number') {
    currentVersion = result.user_version;
  }

  const pendingMigrations = migrations
    .filter((m) => m.version > currentVersion)
    .sort((a, b) => a.version - b.version);

  for (const migration of pendingMigrations) {
    if (db.withTransactionAsync) {
      await db.withTransactionAsync(async () => {
        await migration.up(db);
        await db.execAsync(`PRAGMA user_version = ${migration.version};`);
      });
    } else {
      await migration.up(db);
      await db.execAsync(`PRAGMA user_version = ${migration.version};`);
    }
    currentVersion = migration.version;
  }

  return currentVersion;
}

export { v001Migration };
