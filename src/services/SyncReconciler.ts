import { getDatabase, getFileStatesByStatus } from '../db';
import type { FileState, SyncRule } from '../types';

export class SyncReconciler {
  static async getPendingFiles(rule: SyncRule): Promise<FileState[]> {
    const db = await getDatabase();
    const pending = await getFileStatesByStatus(db, rule.id, 'PENDING');
    const failed = await getFileStatesByStatus(db, rule.id, 'FAILED');
    
    let all = [...pending, ...failed];
    
    if (rule.sync_mode === 'ECHO') {
      const deletedLocally = await getFileStatesByStatus(db, rule.id, 'DELETED_LOCALLY');
      all = [...all, ...deletedLocally];
    }

    return all.sort((a, b) => {
      if (a.attempts !== b.attempts) {
        return a.attempts - b.attempts;
      }
      return new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime();
    });
  }
}
