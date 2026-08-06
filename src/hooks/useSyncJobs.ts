import { useState, useEffect, useCallback } from 'react';
import { getDatabase } from '../db';
import {
  getAllFileStates
} from '../db/repositories';
import type { FileState } from '../types';

export function useSyncJobs() {
  const [history, setHistory] = useState<FileState[]>([]);
  const [pending, setPending] = useState<FileState[]>([]);
  const [failed, setFailed] = useState<FileState[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const db = await getDatabase();
      const data = await getAllFileStates(db);
      
      const p = data.filter(f => f.status === 'PENDING' || f.status === 'UPLOADING');
      const f = data.filter(f => f.status === 'FAILED');
      
      setHistory(data);
      setPending(p);
      setFailed(f);
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Unknown error fetching jobs'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { history, pending, failed, loading, error, refresh };
}
