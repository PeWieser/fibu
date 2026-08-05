import Database from 'better-sqlite3';
import type { DatabaseLike } from '../../src/db/types';

export function createTestDb(): DatabaseLike {
  const rawDb = new Database(':memory:');
  rawDb.pragma('foreign_keys = ON');

  return {
    async execAsync(sql: string): Promise<void> {
      rawDb.exec(sql);
    },
    async runAsync(
      source: string,
      ...params: unknown[]
    ): Promise<{ lastInsertRowId: number; changes: number }> {
      const stmt = rawDb.prepare(source);
      const res = stmt.run(...params);
      return {
        lastInsertRowId: Number(res.lastInsertRowid),
        changes: res.changes,
      };
    },
    async getFirstAsync<T>(
      source: string,
      ...params: unknown[]
    ): Promise<T | null> {
      const stmt = rawDb.prepare(source);
      const row = stmt.get(...params);
      return (row as T) ?? null;
    },
    async getAllAsync<T>(
      source: string,
      ...params: unknown[]
    ): Promise<T[]> {
      const stmt = rawDb.prepare(source);
      const rows = stmt.all(...params);
      return rows as T[];
    },
    async withTransactionAsync(task: () => Promise<void>): Promise<void> {
      await task();
    },
  };
}
