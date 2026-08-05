import type { DBConnection } from '../types';
import type { FileState, FileStatus } from '../../types';

interface FileStateRow {
  id: string;
  local_uri: string;
  file_hash: string | null;
  cloud_path: string;
  rule_id: string;
  status: FileStatus;
  bytes: number;
  attempts: number;
  last_error: string | null;
  updated_at: string;
}

function mapRowToFileState(row: FileStateRow): FileState {
  return {
    id: row.id,
    local_uri: row.local_uri,
    file_hash: row.file_hash ?? undefined,
    cloud_path: row.cloud_path,
    rule_id: row.rule_id,
    status: row.status,
    bytes: row.bytes,
    attempts: row.attempts,
    last_error: row.last_error ?? undefined,
    updated_at: row.updated_at,
  };
}

export async function createFileState(
  db: DBConnection,
  fileState: Omit<FileState, 'id' | 'updated_at'> & { id?: string; updated_at?: string }
): Promise<FileState> {
  const id = fileState.id ?? `file-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
  const updatedAt = fileState.updated_at ?? new Date().toISOString();

  await db.runAsync(
    `INSERT INTO FileState (
      id, local_uri, file_hash, cloud_path, rule_id, status, bytes, attempts, last_error, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    fileState.local_uri,
    fileState.file_hash ?? null,
    fileState.cloud_path,
    fileState.rule_id,
    fileState.status,
    fileState.bytes,
    fileState.attempts ?? 0,
    fileState.last_error ?? null,
    updatedAt
  );

  return {
    ...fileState,
    id,
    attempts: fileState.attempts ?? 0,
    updated_at: updatedAt,
  };
}

export async function getFileStateById(
  db: DBConnection,
  id: string
): Promise<FileState | null> {
  const row = await db.getFirstAsync<FileStateRow>(
    'SELECT * FROM FileState WHERE id = ?',
    id
  );
  if (!row) return null;
  return mapRowToFileState(row);
}

export async function getFileStateByRuleAndUri(
  db: DBConnection,
  ruleId: string,
  localUri: string
): Promise<FileState | null> {
  const row = await db.getFirstAsync<FileStateRow>(
    'SELECT * FROM FileState WHERE rule_id = ? AND local_uri = ?',
    ruleId,
    localUri
  );
  if (!row) return null;
  return mapRowToFileState(row);
}

export async function getFileStatesByRuleId(
  db: DBConnection,
  ruleId: string
): Promise<FileState[]> {
  const rows = await db.getAllAsync<FileStateRow>(
    'SELECT * FROM FileState WHERE rule_id = ? ORDER BY updated_at DESC',
    ruleId
  );
  return rows.map(mapRowToFileState);
}

export async function getFileStatesByStatus(
  db: DBConnection,
  ruleId: string,
  status: FileStatus
): Promise<FileState[]> {
  const rows = await db.getAllAsync<FileStateRow>(
    'SELECT * FROM FileState WHERE rule_id = ? AND status = ? ORDER BY updated_at DESC',
    ruleId,
    status
  );
  return rows.map(mapRowToFileState);
}

export async function getAllFileStates(
  db: DBConnection
): Promise<FileState[]> {
  const rows = await db.getAllAsync<FileStateRow>(
    'SELECT * FROM FileState ORDER BY updated_at DESC'
  );
  return rows.map(mapRowToFileState);
}

export async function updateFileState(
  db: DBConnection,
  fileState: FileState
): Promise<FileState> {
  const updatedAt = new Date().toISOString();
  await db.runAsync(
    `UPDATE FileState SET
      local_uri = ?,
      file_hash = ?,
      cloud_path = ?,
      rule_id = ?,
      status = ?,
      bytes = ?,
      attempts = ?,
      last_error = ?,
      updated_at = ?
    WHERE id = ?`,
    fileState.local_uri,
    fileState.file_hash ?? null,
    fileState.cloud_path,
    fileState.rule_id,
    fileState.status,
    fileState.bytes,
    fileState.attempts,
    fileState.last_error ?? null,
    updatedAt,
    fileState.id
  );

  return {
    ...fileState,
    updated_at: updatedAt,
  };
}

export async function updateFileStatus(
  db: DBConnection,
  id: string,
  status: FileStatus,
  error?: string,
  incrementAttempts: boolean = false
): Promise<void> {
  const updatedAt = new Date().toISOString();
  await db.runAsync(
    `UPDATE FileState SET
      status = ?,
      last_error = ?,
      attempts = CASE WHEN ? THEN attempts + 1 ELSE attempts END,
      updated_at = ?
    WHERE id = ?`,
    status,
    error ?? null,
    incrementAttempts ? 1 : 0,
    updatedAt,
    id
  );
}

export async function deleteFileState(
  db: DBConnection,
  id: string
): Promise<boolean> {
  const result = await db.runAsync('DELETE FROM FileState WHERE id = ?', id);
  return result.changes > 0;
}

export async function upsertFileState(
  db: DBConnection,
  fileState: Omit<FileState, 'id' | 'updated_at'> & { id?: string; updated_at?: string }
): Promise<FileState> {
  const existing = await getFileStateByRuleAndUri(db, fileState.rule_id, fileState.local_uri);
  const id = existing?.id ?? fileState.id ?? `file-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
  const updatedAt = new Date().toISOString();

  await db.runAsync(
    `INSERT INTO FileState (
      id, local_uri, file_hash, cloud_path, rule_id, status, bytes, attempts, last_error, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(rule_id, local_uri) DO UPDATE SET
      file_hash = excluded.file_hash,
      cloud_path = excluded.cloud_path,
      status = excluded.status,
      bytes = excluded.bytes,
      attempts = excluded.attempts,
      last_error = excluded.last_error,
      updated_at = excluded.updated_at`,
    id,
    fileState.local_uri,
    fileState.file_hash ?? null,
    fileState.cloud_path,
    fileState.rule_id,
    fileState.status,
    fileState.bytes,
    fileState.attempts ?? 0,
    fileState.last_error ?? null,
    updatedAt
  );

  return {
    ...fileState,
    id,
    attempts: fileState.attempts ?? 0,
    updated_at: updatedAt,
  };
}
