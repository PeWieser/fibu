import { useState, useEffect, useCallback } from 'react';
import { getDatabase } from '../db';
import {
  getAllCloudRemotes,
  createCloudRemote,
  deleteCloudRemote as deleteCloudRemoteRepo,
  updateSpaceUsage as updateSpaceUsageRepo
} from '../db/repositories';
import type { CloudRemote } from '../types';

export function useCloudRemotes() {
  const [remotes, setRemotes] = useState<CloudRemote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const db = await getDatabase();
      const data = await getAllCloudRemotes(db);
      setRemotes(data);
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Unknown error fetching remotes'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const addRemote = useCallback(async (remote: Omit<CloudRemote, 'id'> & { id?: string }) => {
    try {
      const db = await getDatabase();
      await createCloudRemote(db, remote);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Failed to add remote'));
      throw e;
    }
  }, [refresh]);

  const deleteRemote = useCallback(async (id: string) => {
    try {
      const db = await getDatabase();
      await deleteCloudRemoteRepo(db, id);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Failed to delete remote'));
      throw e;
    }
  }, [refresh]);

  const updateUsage = useCallback(async (id: string, usedSpaceBytes: number, totalSpaceBytes: number) => {
    try {
      const db = await getDatabase();
      await updateSpaceUsageRepo(db, id, usedSpaceBytes, totalSpaceBytes);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Failed to update space usage'));
      throw e;
    }
  }, [refresh]);

  return { remotes, loading, error, refresh, deleteRemote, addRemote, updateUsage };
}
