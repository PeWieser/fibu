/**
 * RcloneTypes.ts — All RPC request/response types for the rclone native bridge.
 */

import type { Provider } from '../../../src/types';

// Re-export so consumers of this module don't need to import from src/types directly.
export type { Provider } from '../../../src/types';

/** Union alias kept for naming consistency inside the rclone module. */
export type ProviderType = Provider;

// ---------------------------------------------------------------------------
// Request specs
// ---------------------------------------------------------------------------

/** Describes a cloud remote to be created in rclone's config. */
export interface RemoteSpec {
  /** Human-readable name used as the rclone remote name (e.g. "my-drive"). */
  name: string;
  /** Cloud provider identifier. */
  provider: ProviderType;
  /** Provider-specific key/value config (e.g. token, client_id, …). */
  options?: Record<string, string>;
}

/** Tuning parameters passed to rclone sync operations. */
export interface SyncOptions {
  /** Number of parallel file transfers (default: rclone default). */
  transfers?: number;
  /** Number of parallel checkers (default: rclone default). */
  checkers?: number;
  /** Bandwidth limit string, e.g. "10M" or "1M:10M". */
  bwlimit?: string;
  /** Number of retries on transient errors. */
  retries?: number;
  /** If true, perform a dry run without modifying any files. */
  dryRun?: boolean;
  /** If true, request progress events for this job. */
  progress?: boolean;
}

// ---------------------------------------------------------------------------
// Response types
// ---------------------------------------------------------------------------

/** Disk quota information returned by `operations/about`. */
export interface QuotaInfo {
  totalBytes: number;
  usedBytes: number;
  freeBytes: number;
}

/** Parsed rclone config dump: remote name → key/value pairs. */
export type RcloneConfig = Record<string, Record<string, string>>;

/** Result of a completed OAuth authorisation flow. */
export interface AuthorizeResult {
  /** Provider that was authorised. */
  provider: ProviderType;
  /** The rclone config-section name created/updated. */
  configName: string;
  /** JSON-encoded token blob returned by rclone. */
  token: string;
}

// ---------------------------------------------------------------------------
// Event payloads
// ---------------------------------------------------------------------------

/** Progress event emitted during an active sync job. */
export interface RcloneProgressEvent {
  /** Opaque job identifier returned by sync/sync. */
  jobId: string;
  /** Bytes transferred so far. */
  transferred: number;
  /** Total bytes to transfer. */
  total: number;
  /** Transfer speed in bytes/second. */
  speed: number;
  /** Estimated seconds remaining (-1 if unknown). */
  eta: number;
  /** Completion percentage 0–100. */
  percentage: number;
}

/** Status change event emitted when a job finishes or errors. */
export interface RcloneJobEvent {
  /** Opaque job identifier. */
  jobId: string;
  /** Current job status. */
  status: 'running' | 'success' | 'error';
  /** Human-readable error message, present only when status === 'error'. */
  error?: string;
}
