import type { DBConnection } from '../types';
import type { CloudRemote, Provider } from '../../types';
import { decryptConfig, encryptConfig } from '../crypto';

interface CloudRemoteRow {
  id: string;
  name: string;
  provider: Provider;
  rclone_config: string;
  is_encrypted: number;
  total_space_bytes: number;
  used_space_bytes: number;
  last_probed_at: string | null;
}

async function mapRowToCloudRemote(row: CloudRemoteRow): Promise<CloudRemote> {
  return {
    id: row.id,
    name: row.name,
    provider: row.provider,
    rclone_config: await decryptConfig(row.rclone_config),
    is_encrypted: Boolean(row.is_encrypted),
    total_space_bytes: row.total_space_bytes,
    used_space_bytes: row.used_space_bytes,
    last_probed_at: row.last_probed_at ?? undefined,
  };
}

export async function createCloudRemote(
  db: DBConnection,
  remote: Omit<CloudRemote, 'id'> & { id?: string }
): Promise<CloudRemote> {
  const id = remote.id ?? `remote-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
  const encryptedConfig = await encryptConfig(remote.rclone_config);

  await db.runAsync(
    `INSERT INTO CloudRemotes (
      id, name, provider, rclone_config, is_encrypted, total_space_bytes, used_space_bytes, last_probed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    remote.name,
    remote.provider,
    encryptedConfig,
    remote.is_encrypted ? 1 : 0,
    remote.total_space_bytes,
    remote.used_space_bytes,
    remote.last_probed_at ?? null
  );

  return {
    ...remote,
    id,
  };
}

export async function getCloudRemoteById(
  db: DBConnection,
  id: string
): Promise<CloudRemote | null> {
  const row = await db.getFirstAsync<CloudRemoteRow>(
    'SELECT * FROM CloudRemotes WHERE id = ?',
    id
  );
  if (!row) return null;
  return mapRowToCloudRemote(row);
}

export async function getAllCloudRemotes(
  db: DBConnection
): Promise<CloudRemote[]> {
  const rows = await db.getAllAsync<CloudRemoteRow>(
    'SELECT * FROM CloudRemotes ORDER BY name ASC'
  );
  return Promise.all(rows.map(mapRowToCloudRemote));
}

export async function updateCloudRemote(
  db: DBConnection,
  remote: CloudRemote
): Promise<CloudRemote> {
  const encryptedConfig = await encryptConfig(remote.rclone_config);

  await db.runAsync(
    `UPDATE CloudRemotes SET
      name = ?,
      provider = ?,
      rclone_config = ?,
      is_encrypted = ?,
      total_space_bytes = ?,
      used_space_bytes = ?,
      last_probed_at = ?
    WHERE id = ?`,
    remote.name,
    remote.provider,
    encryptedConfig,
    remote.is_encrypted ? 1 : 0,
    remote.total_space_bytes,
    remote.used_space_bytes,
    remote.last_probed_at ?? null,
    remote.id
  );

  return remote;
}

export async function deleteCloudRemote(
  db: DBConnection,
  id: string
): Promise<boolean> {
  const result = await db.runAsync('DELETE FROM CloudRemotes WHERE id = ?', id);
  return result.changes > 0;
}

export async function updateSpaceUsage(
  db: DBConnection,
  id: string,
  usedSpaceBytes: number,
  totalSpaceBytes: number
): Promise<void> {
  const lastProbedAt = new Date().toISOString();
  await db.runAsync(
    `UPDATE CloudRemotes SET
      used_space_bytes = ?,
      total_space_bytes = ?,
      last_probed_at = ?
    WHERE id = ?`,
    usedSpaceBytes,
    totalSpaceBytes,
    lastProbedAt,
    id
  );
}
