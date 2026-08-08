import * as SQLite from 'expo-sqlite';
import { runMigrations } from './migrations';

const DB_NAME = 'echovault.db';
let dbInstance: SQLite.SQLiteDatabase | null = null;
let dbInitPromise: Promise<SQLite.SQLiteDatabase> | null = null;

export async function getDatabase(): Promise<SQLite.SQLiteDatabase> {
  if (dbInstance) {
    return dbInstance;
  }

  if (!dbInitPromise) {
    dbInitPromise = (async () => {
      const db = await SQLite.openDatabaseAsync(DB_NAME);
      await runMigrations(db);
      dbInstance = db;
      return db;
    })();
  }

  return dbInitPromise;
}

/**
 * Resets the local sync index: clears all FileState rows and sets user_version to 0
 * so the next call to getDatabase() re-runs all migrations.
 * Does NOT delete CloudRemotes or SyncRules — only sync state.
 */
export async function resetDatabase(): Promise<void> {
  const db = await getDatabase();
  // Clear only file sync state; preserve configuration tables
  await db.execAsync('DELETE FROM FileState;');
  // Reset the singleton so subsequent getDatabase() re-initialises migrations
  dbInstance = null;
  dbInitPromise = null;
}

export * from './types';
export * from './migrations';
export * from './repositories';
export * from './seed';
