import type { DBConnection } from '../types';
import type { SyncRule, MediaType, SyncMode } from '../../types';

interface SyncRuleRow {
  id: string;
  source_album_id: string;
  media_type: MediaType;
  target_remote_id: string;
  sync_mode: SyncMode;
  requires_wifi: number;
  requires_charging: number;
  is_enabled: number;
  created_at: string;
}

function mapRowToSyncRule(row: SyncRuleRow): SyncRule {
  return {
    id: row.id,
    source_album_id: row.source_album_id,
    media_type: row.media_type,
    target_remote_id: row.target_remote_id,
    sync_mode: row.sync_mode,
    requires_wifi: Boolean(row.requires_wifi),
    requires_charging: Boolean(row.requires_charging),
    is_enabled: Boolean(row.is_enabled),
    created_at: row.created_at,
  };
}

export async function createSyncRule(
  db: DBConnection,
  rule: Omit<SyncRule, 'id' | 'created_at'> & { id?: string; created_at?: string }
): Promise<SyncRule> {
  const id = rule.id ?? `rule-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
  const createdAt = rule.created_at ?? new Date().toISOString();

  await db.runAsync(
    `INSERT INTO SyncRules (
      id, source_album_id, media_type, target_remote_id, sync_mode, requires_wifi, requires_charging, is_enabled, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    rule.source_album_id,
    rule.media_type,
    rule.target_remote_id,
    rule.sync_mode,
    rule.requires_wifi ? 1 : 0,
    rule.requires_charging ? 1 : 0,
    rule.is_enabled ? 1 : 0,
    createdAt
  );

  return {
    ...rule,
    id,
    created_at: createdAt,
  };
}

export async function getSyncRuleById(
  db: DBConnection,
  id: string
): Promise<SyncRule | null> {
  const row = await db.getFirstAsync<SyncRuleRow>(
    'SELECT * FROM SyncRules WHERE id = ?',
    id
  );
  if (!row) return null;
  return mapRowToSyncRule(row);
}

export async function getAllSyncRules(
  db: DBConnection
): Promise<SyncRule[]> {
  const rows = await db.getAllAsync<SyncRuleRow>(
    'SELECT * FROM SyncRules ORDER BY created_at DESC'
  );
  return rows.map(mapRowToSyncRule);
}

export async function getSyncRulesByRemoteId(
  db: DBConnection,
  targetRemoteId: string
): Promise<SyncRule[]> {
  const rows = await db.getAllAsync<SyncRuleRow>(
    'SELECT * FROM SyncRules WHERE target_remote_id = ? ORDER BY created_at DESC',
    targetRemoteId
  );
  return rows.map(mapRowToSyncRule);
}

export async function updateSyncRule(
  db: DBConnection,
  rule: SyncRule
): Promise<SyncRule> {
  await db.runAsync(
    `UPDATE SyncRules SET
      source_album_id = ?,
      media_type = ?,
      target_remote_id = ?,
      sync_mode = ?,
      requires_wifi = ?,
      requires_charging = ?,
      is_enabled = ?
    WHERE id = ?`,
    rule.source_album_id,
    rule.media_type,
    rule.target_remote_id,
    rule.sync_mode,
    rule.requires_wifi ? 1 : 0,
    rule.requires_charging ? 1 : 0,
    rule.is_enabled ? 1 : 0,
    rule.id
  );

  return rule;
}

export async function deleteSyncRule(
  db: DBConnection,
  id: string
): Promise<boolean> {
  const result = await db.runAsync('DELETE FROM SyncRules WHERE id = ?', id);
  return result.changes > 0;
}

export async function toggleSyncRuleEnabled(
  db: DBConnection,
  id: string,
  isEnabled: boolean
): Promise<void> {
  await db.runAsync(
    'UPDATE SyncRules SET is_enabled = ? WHERE id = ?',
    isEnabled ? 1 : 0,
    id
  );
}
