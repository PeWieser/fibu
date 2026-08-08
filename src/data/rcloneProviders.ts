import type { Provider } from '../types';

export interface RcloneProvider {
  /** Unique UI identifier. S3-compat entries use 's3_<slug>' format. */
  id: string;
  /** Actual rclone backend type passed to config/create. */
  rcloneType: Provider;
  name: string;
  category: RcloneCategory;
  description: string;
  requiresOAuth: boolean;
  /** For s3-compatible providers: value of the rclone `provider` param. */
  s3Provider?: string;
}

export type RcloneCategory =
  | 'Google' | 'Microsoft' | 'Consumer Cloud' | 'Object Storage'
  | 'S3 Compatible' | 'Decentralised' | 'Server Protocol' | 'Virtual Remote' | 'Other';

export const RCLONE_PROVIDERS: RcloneProvider[] = [
  // Google
  { id: 'drive', rcloneType: 'drive', name: 'Google Drive', category: 'Google', description: "Google's cloud storage with 15 GB free", requiresOAuth: true },
  { id: 'googlephotos', rcloneType: 'googlephotos', name: 'Google Photos', category: 'Google', description: 'Backup & sync to Google Photos library', requiresOAuth: true },
  { id: 'googlecloudstorage', rcloneType: 'googlecloudstorage', name: 'Google Cloud Storage', category: 'Google', description: 'Google Cloud Storage (GCS) buckets', requiresOAuth: true },
  // Microsoft
  { id: 'onedrive', rcloneType: 'onedrive', name: 'Microsoft OneDrive', category: 'Microsoft', description: 'OneDrive personal, business and SharePoint', requiresOAuth: true },
  { id: 'azureblob', rcloneType: 'azureblob', name: 'Azure Blob Storage', category: 'Microsoft', description: 'Microsoft Azure Blob Storage', requiresOAuth: false },
  { id: 'azurefiles', rcloneType: 'azurefiles', name: 'Azure Files', category: 'Microsoft', description: 'Microsoft Azure Files (SMB-compatible cloud)', requiresOAuth: false },
  // Consumer Cloud
  { id: 'dropbox', rcloneType: 'dropbox', name: 'Dropbox', category: 'Consumer Cloud', description: 'Sync to your Dropbox account', requiresOAuth: true },
  { id: 'box', rcloneType: 'box', name: 'Box', category: 'Consumer Cloud', description: 'Box cloud storage for businesses and individuals', requiresOAuth: true },
  { id: 'mega', rcloneType: 'mega', name: 'MEGA', category: 'Consumer Cloud', description: 'MEGA secure cloud storage with 20 GB free', requiresOAuth: false },
  { id: 'pcloud', rcloneType: 'pcloud', name: 'pCloud', category: 'Consumer Cloud', description: 'European cloud storage with lifetime plans', requiresOAuth: true },
  { id: 'proton', rcloneType: 'proton', name: 'Proton Drive', category: 'Consumer Cloud', description: 'End-to-end encrypted storage by Proton', requiresOAuth: true },
  { id: 'filen', rcloneType: 'filen', name: 'Filen', category: 'Consumer Cloud', description: 'Zero-knowledge encrypted cloud storage', requiresOAuth: false },
  { id: 'yandex', rcloneType: 'yandex', name: 'Yandex Disk', category: 'Consumer Cloud', description: 'Yandex cloud storage (10 GB free)', requiresOAuth: true },
  { id: 'jottacloud', rcloneType: 'jottacloud', name: 'Jottacloud', category: 'Consumer Cloud', description: 'Norwegian cloud storage with unlimited option', requiresOAuth: true },
  { id: 'koofr', rcloneType: 'koofr', name: 'Koofr', category: 'Consumer Cloud', description: 'European cloud storage, WebDAV-compatible', requiresOAuth: true },
  { id: 'mailru', rcloneType: 'mailru', name: 'Mail.ru Cloud', category: 'Consumer Cloud', description: 'Mail.ru Cloud (8 GB free)', requiresOAuth: true },
  { id: 'zoho', rcloneType: 'zoho', name: 'Zoho WorkDrive', category: 'Consumer Cloud', description: "Zoho's cloud storage for teams", requiresOAuth: true },
  { id: 'hidrive', rcloneType: 'hidrive', name: 'HiDrive', category: 'Consumer Cloud', description: 'STRATO HiDrive (Germany, GDPR-compliant)', requiresOAuth: true },
  { id: 'pikpak', rcloneType: 'pikpak', name: 'PikPak', category: 'Consumer Cloud', description: 'High-speed cloud with offline download', requiresOAuth: true },
  { id: 'premiumizeme', rcloneType: 'premiumizeme', name: 'Premiumize.me', category: 'Consumer Cloud', description: 'Premium cloud with torrent downloader', requiresOAuth: true },
  { id: 'putio', rcloneType: 'putio', name: 'Put.io', category: 'Consumer Cloud', description: 'Stream and download files via Put.io', requiresOAuth: true },
  { id: 'opendrive', rcloneType: 'opendrive', name: 'OpenDrive', category: 'Consumer Cloud', description: 'OpenDrive cloud storage and backup', requiresOAuth: false },
  { id: 'sugarsync', rcloneType: 'sugarsync', name: 'SugarSync', category: 'Consumer Cloud', description: 'SugarSync cloud backup and sync', requiresOAuth: false },
  { id: 'linkbox', rcloneType: 'linkbox', name: 'Linkbox', category: 'Consumer Cloud', description: 'Linkbox personal cloud storage', requiresOAuth: false },
  { id: 'ulozto', rcloneType: 'ulozto', name: 'Uloz.to', category: 'Consumer Cloud', description: 'Czech file-sharing and storage service', requiresOAuth: false },
  { id: 'seafile', rcloneType: 'seafile', name: 'Seafile', category: 'Consumer Cloud', description: 'Open-source self-hosted cloud (also Seafile.com)', requiresOAuth: false },
  { id: 'sharefile', rcloneType: 'sharefile', name: 'Citrix ShareFile', category: 'Consumer Cloud', description: 'Secure business file sharing by Citrix', requiresOAuth: true },
  { id: 'quatrix', rcloneType: 'quatrix', name: 'Quatrix', category: 'Consumer Cloud', description: 'Quatrix secure file exchange platform', requiresOAuth: false },
  { id: 'filefabric', rcloneType: 'filefabric', name: 'Storage Made Easy', category: 'Consumer Cloud', description: 'FileFabric enterprise cloud gateway', requiresOAuth: true },
  // Object Storage
  { id: 's3_aws', rcloneType: 's3', name: 'Amazon S3', category: 'Object Storage', description: 'AWS Simple Storage Service', requiresOAuth: false, s3Provider: 'AWS' },
  { id: 'b2', rcloneType: 'b2', name: 'Backblaze B2', category: 'Object Storage', description: 'Backblaze B2 Cloud Storage (native API)', requiresOAuth: false },
  { id: 'swift', rcloneType: 'swift', name: 'OpenStack Swift', category: 'Object Storage', description: 'OpenStack Swift / Rackspace Cloud Files', requiresOAuth: false },
  { id: 'oracleobjectstorage', rcloneType: 'oracleobjectstorage', name: 'Oracle Object Storage', category: 'Object Storage', description: 'Oracle Cloud Infrastructure Object Storage', requiresOAuth: false },
  { id: 'idrive', rcloneType: 'idrive', name: 'IDrive e2', category: 'Object Storage', description: 'IDrive e2 S3-compatible cloud storage', requiresOAuth: false },
  // S3 Compatible
  { id: 's3_cloudflare', rcloneType: 's3', name: 'Cloudflare R2', category: 'S3 Compatible', description: 'Zero-egress-fee object storage by Cloudflare', requiresOAuth: false, s3Provider: 'Cloudflare' },
  { id: 's3_wasabi', rcloneType: 's3', name: 'Wasabi', category: 'S3 Compatible', description: 'Low-cost, high-performance S3-compatible storage', requiresOAuth: false, s3Provider: 'Wasabi' },
  { id: 's3_backblaze', rcloneType: 's3', name: 'Backblaze B2 (S3)', category: 'S3 Compatible', description: 'Backblaze B2 via S3-compatible API', requiresOAuth: false, s3Provider: 'Backblaze' },
  { id: 's3_digitalocean', rcloneType: 's3', name: 'DigitalOcean Spaces', category: 'S3 Compatible', description: 'S3-compatible object storage by DigitalOcean', requiresOAuth: false, s3Provider: 'DigitalOcean' },
  { id: 's3_linode', rcloneType: 's3', name: 'Linode Object Storage', category: 'S3 Compatible', description: 'Akamai Linode S3-compatible object storage', requiresOAuth: false, s3Provider: 'Linode' },
  { id: 's3_scaleway', rcloneType: 's3', name: 'Scaleway Object Storage', category: 'S3 Compatible', description: 'French cloud S3-compatible object storage', requiresOAuth: false, s3Provider: 'Scaleway' },
  { id: 's3_minio', rcloneType: 's3', name: 'MinIO', category: 'S3 Compatible', description: 'Self-hosted S3-compatible object storage', requiresOAuth: false, s3Provider: 'Minio' },
  { id: 's3_alibaba', rcloneType: 's3', name: 'Alibaba OSS', category: 'S3 Compatible', description: 'Alibaba Cloud Object Storage Service', requiresOAuth: false, s3Provider: 'Alibaba' },
  { id: 's3_tencent', rcloneType: 's3', name: 'Tencent COS', category: 'S3 Compatible', description: 'Tencent Cloud Object Storage', requiresOAuth: false, s3Provider: 'TencentCOS' },
  { id: 's3_huawei', rcloneType: 's3', name: 'Huawei OBS', category: 'S3 Compatible', description: 'Huawei Cloud Object Storage Service', requiresOAuth: false, s3Provider: 'HuaweiOBS' },
  { id: 's3_other', rcloneType: 's3', name: 'S3 Compatible (other)', category: 'S3 Compatible', description: 'Any other S3-compatible storage endpoint', requiresOAuth: false, s3Provider: 'Other' },
  // Decentralised
  { id: 'storj', rcloneType: 'storj', name: 'Storj', category: 'Decentralised', description: 'Decentralised, encrypted object storage network', requiresOAuth: false },
  { id: 'sia', rcloneType: 'sia', name: 'Sia', category: 'Decentralised', description: 'Decentralised storage on the Sia network', requiresOAuth: false },
  // Server protocols
  { id: 'sftp', rcloneType: 'sftp', name: 'SFTP', category: 'Server Protocol', description: 'SSH File Transfer Protocol (port 22)', requiresOAuth: false },
  { id: 'ftp', rcloneType: 'ftp', name: 'FTP', category: 'Server Protocol', description: 'File Transfer Protocol', requiresOAuth: false },
  { id: 'ftps', rcloneType: 'ftps', name: 'FTPS', category: 'Server Protocol', description: 'FTP with implicit or explicit TLS', requiresOAuth: false },
  { id: 'webdav', rcloneType: 'webdav', name: 'WebDAV', category: 'Server Protocol', description: 'WebDAV (Nextcloud, ownCloud, Nginx...)', requiresOAuth: false },
  { id: 'smb', rcloneType: 'smb', name: 'SMB / CIFS', category: 'Server Protocol', description: 'Windows / Samba network file share', requiresOAuth: false },
  { id: 'nfs', rcloneType: 'nfs', name: 'NFS', category: 'Server Protocol', description: 'Network File System (Linux / Unix shares)', requiresOAuth: false },
  { id: 'hdfs', rcloneType: 'hdfs', name: 'Hadoop HDFS', category: 'Server Protocol', description: 'Hadoop Distributed File System', requiresOAuth: false },
  // Virtual remotes
  { id: 'union', rcloneType: 'union', name: 'Union', category: 'Virtual Remote', description: 'Combine multiple remotes into one virtual remote', requiresOAuth: false },
  { id: 'crypt', rcloneType: 'crypt', name: 'Crypt', category: 'Virtual Remote', description: 'Encrypt files on any other remote (AES-256)', requiresOAuth: false },
  { id: 'alias', rcloneType: 'alias', name: 'Alias', category: 'Virtual Remote', description: 'Create a named alias for another remote path', requiresOAuth: false },
  { id: 'chunker', rcloneType: 'chunker', name: 'Chunker', category: 'Virtual Remote', description: 'Split large files into smaller chunks', requiresOAuth: false },
  { id: 'compress', rcloneType: 'compress', name: 'Compress', category: 'Virtual Remote', description: 'Compress files before storing on another remote', requiresOAuth: false },
  { id: 'cache', rcloneType: 'cache', name: 'Cache', category: 'Virtual Remote', description: 'Cache files locally for faster access', requiresOAuth: false },
  { id: 'combine', rcloneType: 'combine', name: 'Combine', category: 'Virtual Remote', description: 'Combine multiple remote paths into one namespace', requiresOAuth: false },
  { id: 'hasher', rcloneType: 'hasher', name: 'Hasher', category: 'Virtual Remote', description: 'Add or override hash checksums on any remote', requiresOAuth: false },
  // Other
  { id: 'internetarchive', rcloneType: 'internetarchive', name: 'Internet Archive', category: 'Other', description: 'Upload to archive.org collections', requiresOAuth: false },
];

export const PROVIDER_CATEGORIES: RcloneCategory[] = [
  'Google', 'Microsoft', 'Consumer Cloud', 'Object Storage',
  'S3 Compatible', 'Decentralised', 'Server Protocol', 'Virtual Remote', 'Other',
];

export function filterProviders(query: string): RcloneProvider[] {
  const q = query.trim().toLowerCase();
  if (!q) return RCLONE_PROVIDERS;
  return RCLONE_PROVIDERS.filter(
    (p) =>
      p.name.toLowerCase().includes(q) ||
      p.category.toLowerCase().includes(q) ||
      p.description.toLowerCase().includes(q) ||
      p.rcloneType.toLowerCase().includes(q),
  );
}
