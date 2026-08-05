import type { DBConnection } from './types';
import {
  createCloudRemote,
  createSyncRule,
  createFileState,
} from './repositories';
import type { FileStatus, MediaType, Provider, SyncMode } from '../types';

export async function seedDatabase(db: DBConnection): Promise<void> {
  // 1. Create 3 CloudRemotes
  const remote1 = await createCloudRemote(db, {
    id: 'remote-1',
    name: 'Google Drive Primary',
    provider: 'drive' as Provider,
    rclone_config: '[drive]\ntype = drive\nscope = drive\ntoken = {"access_token":"mock_token"}',
    is_encrypted: false,
    total_space_bytes: 15 * 1024 * 1024 * 1024, // 15 GB
    used_space_bytes: 5 * 1024 * 1024 * 1024, // 5 GB
    last_probed_at: new Date().toISOString(),
  });

  const remote2 = await createCloudRemote(db, {
    id: 'remote-2',
    name: 'Mega Encrypted Vault',
    provider: 'mega' as Provider,
    rclone_config: '[mega]\ntype = mega\nuser = user@example.com\npass = encrypted_pass',
    is_encrypted: true,
    total_space_bytes: 50 * 1024 * 1024 * 1024, // 50 GB
    used_space_bytes: 12 * 1024 * 1024 * 1024, // 12 GB
    last_probed_at: new Date().toISOString(),
  });

  const remote3 = await createCloudRemote(db, {
    id: 'remote-3',
    name: 'OneDrive Archive',
    provider: 'onedrive' as Provider,
    rclone_config: '[onedrive]\ntype = onedrive\ndrive_id = mock_drive_id',
    is_encrypted: false,
    total_space_bytes: 100 * 1024 * 1024 * 1024, // 100 GB
    used_space_bytes: 40 * 1024 * 1024 * 1024, // 40 GB
    last_probed_at: new Date().toISOString(),
  });

  // 2. Create 4 SyncRules
  const rule1 = await createSyncRule(db, {
    id: 'rule-1',
    source_album_id: 'camera_roll',
    media_type: 'PHOTOS' as MediaType,
    target_remote_id: remote1.id,
    sync_mode: 'ECHO' as SyncMode,
    requires_wifi: true,
    requires_charging: false,
    is_enabled: true,
    created_at: new Date(Date.now() - 3600 * 24 * 7 * 1000).toISOString(),
  });

  const rule2 = await createSyncRule(db, {
    id: 'rule-2',
    source_album_id: 'family_videos',
    media_type: 'VIDEOS' as MediaType,
    target_remote_id: remote2.id,
    sync_mode: 'ARCHIVE' as SyncMode,
    requires_wifi: true,
    requires_charging: true,
    is_enabled: true,
    created_at: new Date(Date.now() - 3600 * 24 * 5 * 1000).toISOString(),
  });

  const rule3 = await createSyncRule(db, {
    id: 'rule-3',
    source_album_id: 'whatsapp_images',
    media_type: 'PHOTOS' as MediaType,
    target_remote_id: remote3.id,
    sync_mode: 'ECHO' as SyncMode,
    requires_wifi: false,
    requires_charging: false,
    is_enabled: false,
    created_at: new Date(Date.now() - 3600 * 24 * 3 * 1000).toISOString(),
  });

  const rule4 = await createSyncRule(db, {
    id: 'rule-4',
    source_album_id: 'all_media',
    media_type: 'BOTH' as MediaType,
    target_remote_id: remote1.id,
    sync_mode: 'ARCHIVE' as SyncMode,
    requires_wifi: true,
    requires_charging: false,
    is_enabled: true,
    created_at: new Date(Date.now() - 3600 * 24 * 1 * 1000).toISOString(),
  });

  const rules = [rule1, rule2, rule3, rule4];
  const statuses: FileStatus[] = [
    'PENDING',
    'UPLOADING',
    'SYNCED',
    'FAILED',
    'DELETED_LOCALLY',
  ];

  // 3. Create 100 FileStates
  for (let i = 1; i <= 100; i++) {
    const assignedRule = rules[(i - 1) % rules.length];
    const status = statuses[(i - 1) % statuses.length];
    const isVideo = i % 2 === 0;
    const ext = isVideo ? 'mp4' : 'jpg';

    await createFileState(db, {
      id: `file-state-${i}`,
      local_uri: `file:///storage/emulated/0/DCIM/media_${i}.${ext}`,
      file_hash: `sha256_${i}_hash_${Math.random().toString(36).substring(2, 10)}`,
      cloud_path: `EchoVault/${assignedRule.source_album_id}/media_${i}.${ext}`,
      rule_id: assignedRule.id,
      status,
      bytes: i * 512000 + 1024,
      attempts: status === 'FAILED' ? 3 : status === 'UPLOADING' ? 1 : 0,
      last_error: status === 'FAILED' ? 'Connection dropped during chunk transfer' : undefined,
      updated_at: new Date(Date.now() - i * 1000000).toISOString(),
    });
  }
}
