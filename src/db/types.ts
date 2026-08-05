import type { SQLiteDatabase } from 'expo-sqlite';

export interface DatabaseLike {
  execAsync(sql: string): Promise<void>;
  runAsync(
    source: string,
    ...params: unknown[]
  ): Promise<{ lastInsertRowId: number; changes: number }>;
  getFirstAsync<T>(source: string, ...params: unknown[]): Promise<T | null>;
  getAllAsync<T>(source: string, ...params: unknown[]): Promise<T[]>;
  withTransactionAsync?(task: () => Promise<void>): Promise<void>;
}

export type DBConnection = SQLiteDatabase | DatabaseLike;

export interface Migration {
  version: number;
  up(db: DBConnection): Promise<void>;
}
