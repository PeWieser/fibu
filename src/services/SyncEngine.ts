import { PreflightGates } from './PreflightGates';
import { SyncReconciler } from './SyncReconciler';
import { JobController } from './JobController';
import { getDatabase, getCloudRemoteById } from '../db';
import type { SyncRule } from '../types';
import { Logger } from '../utils/logger';

export class SyncEngine {
  static async runRule(rule: SyncRule, signal?: AbortSignal): Promise<void> {
    Logger.info('Starting runRule', { ruleId: rule.id });

    const preflight = await PreflightGates.canRunRule(rule);
    if (!preflight.canRun) {
      Logger.warn('Preflight failed', { ruleId: rule.id, reason: preflight.reason });
      return;
    }

    const db = await getDatabase();
    const remote = await getCloudRemoteById(db, rule.target_remote_id);
    
    if (!remote) {
      Logger.error('Target remote not found', { ruleId: rule.id, targetRemoteId: rule.target_remote_id });
      throw new Error(`Target remote not found: ${rule.target_remote_id}`);
    }

    const pendingFiles = await SyncReconciler.getPendingFiles(rule);
    if (pendingFiles.length === 0) {
      Logger.info('No pending files for rule', { ruleId: rule.id });
      return;
    }

    Logger.info('Found pending files', { count: pendingFiles.length, ruleId: rule.id });

    const concurrency = 4;
    for (let i = 0; i < pendingFiles.length; i += concurrency) {
      if (signal?.aborted) {
        Logger.warn('Sync aborted', { ruleId: rule.id });
        throw new Error('Aborted');
      }
      
      const batch = pendingFiles.slice(i, i + concurrency);
      
      const batchPromises = batch.map(async (fileState) => {
        const controller = new JobController(fileState, remote.name);
        try {
          await controller.execute(signal);
        } catch (error) {
          Logger.error('JobController failed', { fileId: fileState.id, error });
        }
      });

      await Promise.all(batchPromises);
    }
    
    Logger.info('Completed runRule', { ruleId: rule.id });
  }
}
