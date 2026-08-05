export type Provider = 'drive' | 'mega' | 'onedrive' | 'dropbox' | 'union' | 'crypt';

export type SyncMode = 'ECHO' | 'ARCHIVE';

export type MediaType = 'PHOTOS' | 'VIDEOS' | 'BOTH';

export type FileStatus = 'PENDING' | 'UPLOADING' | 'SYNCED' | 'FAILED' | 'DELETED_LOCALLY';

export interface CloudRemote {
  id: string;
  name: string;
  provider: Provider;
  rclone_config: string;
  is_encrypted: boolean;
  total_space_bytes: number;
  used_space_bytes: number;
  last_probed_at?: string;
}

export interface SyncRule {
  id: string;
  source_album_id: string;
  media_type: MediaType;
  target_remote_id: string;
  sync_mode: SyncMode;
  requires_wifi: boolean;
  requires_charging: boolean;
  is_enabled: boolean;
  created_at: string;
}

export interface FileState {
  id: string;
  local_uri: string;
  file_hash?: string;
  cloud_path: string;
  rule_id: string;
  status: FileStatus;
  bytes: number;
  attempts: number;
  last_error?: string;
  updated_at: string;
}
