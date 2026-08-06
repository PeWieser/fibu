import { RcloneModule } from '../native/RcloneModule';
import { getDatabase, updateFileStatus } from '../db';
import type { FileState } from '../types';

export class JobController {
  constructor(private fileState: FileState, private remoteName: string) {}

  async execute(signal?: AbortSignal): Promise<void> {
    const db = await getDatabase();
    let attemptCount = 0;
    const maxRetries = 3;

    while (attemptCount <= maxRetries) {
      if (signal?.aborted) {
        throw new Error('Aborted');
      }

      try {
        if (this.fileState.status === 'DELETED_LOCALLY') {
          await updateFileStatus(db, this.fileState.id, 'UPLOADING', undefined, true);
          await RcloneModule.deleteRemotePath(this.remoteName, this.fileState.cloud_path);
          await updateFileStatus(db, this.fileState.id, 'SYNCED', undefined, false);
          return;
        } else {
          await updateFileStatus(db, this.fileState.id, 'UPLOADING', undefined, true);
          const targetPath = `${this.remoteName}:${this.fileState.cloud_path}`;
          
          const jobId = await RcloneModule.sync(this.fileState.local_uri, targetPath);
          await this.waitForJob(jobId, signal);
          
          await updateFileStatus(db, this.fileState.id, 'SYNCED', undefined, false);
          return;
        }
      } catch (error: unknown) {
        attemptCount++;
        const errorMessage = error instanceof Error ? error.message : String(error);
        
        if (attemptCount > maxRetries) {
          await updateFileStatus(db, this.fileState.id, 'FAILED', errorMessage, false);
          throw error;
        } else {
          const backoffMs = Math.pow(2, attemptCount) * 1000;
          await new Promise(res => {
            let timeoutId: ReturnType<typeof setTimeout>;
            const onAbort = () => {
              clearTimeout(timeoutId);
              res(undefined);
            };
            if (signal) {
              signal.addEventListener('abort', onAbort, { once: true });
            }
            timeoutId = setTimeout(() => {
              if (signal) {
                signal.removeEventListener('abort', onAbort);
              }
              res(undefined);
            }, backoffMs);
          });
        }
      }
    }
  }

  private waitForJob(jobId: string, signal?: AbortSignal): Promise<void> {
    return new Promise((resolve, reject) => {
      let settled = false;

      const onAbort = () => {
        if (!settled) {
          settled = true;
          sub.remove();
          reject(new Error('Aborted'));
        }
      };

      if (signal?.aborted) {
        onAbort();
        return;
      }

      const sub = RcloneModule.subscribeToJobStatus((event) => {
        if (event.jobId === jobId && !settled) {
          if (event.status === 'success') {
            settled = true;
            sub.remove();
            if (signal) signal.removeEventListener('abort', onAbort);
            resolve();
          } else if (event.status === 'error') {
            settled = true;
            sub.remove();
            if (signal) signal.removeEventListener('abort', onAbort);
            reject(new Error(event.error ?? 'Unknown error'));
          }
        }
      });

      if (signal) {
        signal.addEventListener('abort', onAbort, { once: true });
      }
    });
  }
}
