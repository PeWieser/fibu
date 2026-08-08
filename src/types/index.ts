export type Provider =
  // Major consumer clouds
  | 'drive' | 'onedrive' | 'dropbox' | 'mega' | 'box' | 'pcloud'
  | 'yandex' | 'jottacloud' | 'koofr' | 'mailru' | 'zoho' | 'hidrive'
  | 'proton' | 'filen' | 'premiumizeme' | 'putio' | 'opendrive'
  | 'sugarsync' | 'linkbox' | 'pikpak' | 'ulozto' | 'seafile'
  | 'sharefile' | 'quatrix' | 'filefabric' | 'googlephotos'
  | 'internetarchive'
  // Object / block storage
  | 's3' | 'b2' | 'storj' | 'idrive' | 'azureblob' | 'azurefiles'
  | 'googlecloudstorage' | 'swift' | 'oracleobjectstorage' | 'sia' | 'hdfs'
  // Server protocols
  | 'sftp' | 'ftp' | 'ftps' | 'webdav' | 'smb' | 'nfs'
  // rclone virtual remotes
  | 'union' | 'crypt' | 'alias' | 'chunker' | 'compress' | 'cache'
  | 'combine' | 'hasher'
  // Forward-compatible: any future rclone provider ID
  | (string & {});

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
