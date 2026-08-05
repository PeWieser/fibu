import type { Migration, DBConnection } from '../types';

export const v001Migration: Migration = {
  version: 1,
  async up(db: DBConnection): Promise<void> {
    await db.execAsync(`
      PRAGMA foreign_keys = ON;

      CREATE TABLE IF NOT EXISTS CloudRemotes (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        provider TEXT NOT NULL CHECK (provider IN ('drive', 'mega', 'onedrive', 'dropbox', 'union', 'crypt')),
        rclone_config TEXT NOT NULL,
        is_encrypted INTEGER NOT NULL DEFAULT 0,
        total_space_bytes INTEGER NOT NULL DEFAULT 0,
        used_space_bytes INTEGER NOT NULL DEFAULT 0,
        last_probed_at TEXT
      );

      CREATE TABLE IF NOT EXISTS SyncRules (
        id TEXT PRIMARY KEY NOT NULL,
        source_album_id TEXT NOT NULL,
        media_type TEXT NOT NULL CHECK (media_type IN ('PHOTOS', 'VIDEOS', 'BOTH')),
        target_remote_id TEXT NOT NULL,
        sync_mode TEXT NOT NULL CHECK (sync_mode IN ('ECHO', 'ARCHIVE')),
        requires_wifi INTEGER NOT NULL DEFAULT 0,
        requires_charging INTEGER NOT NULL DEFAULT 0,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (target_remote_id) REFERENCES CloudRemotes (id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS FileState (
        id TEXT PRIMARY KEY NOT NULL,
        local_uri TEXT NOT NULL,
        file_hash TEXT,
        cloud_path TEXT NOT NULL,
        rule_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('PENDING', 'UPLOADING', 'SYNCED', 'FAILED', 'DELETED_LOCALLY')),
        bytes INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (rule_id) REFERENCES SyncRules (id) ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS idx_file_state_rule_status ON FileState (rule_id, status);

      CREATE UNIQUE INDEX IF NOT EXISTS idx_file_state_rule_local_uri ON FileState (rule_id, local_uri);
    `);
  },
};
