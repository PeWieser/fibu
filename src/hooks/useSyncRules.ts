import { useState, useEffect, useCallback } from 'react';
import { getDatabase } from '../db';
import {
  getAllSyncRules,
  createSyncRule,
  deleteSyncRule as deleteSyncRuleRepo,
  toggleSyncRuleEnabled
} from '../db/repositories';
import type { SyncRule } from '../types';

export function useSyncRules() {
  const [rules, setRules] = useState<SyncRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const db = await getDatabase();
      const data = await getAllSyncRules(db);
      setRules(data);
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Unknown error fetching rules'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const addRule = useCallback(async (rule: Omit<SyncRule, 'id' | 'created_at'> & { id?: string; created_at?: string }) => {
    try {
      const db = await getDatabase();
      await createSyncRule(db, rule);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Failed to add rule'));
      throw e;
    }
  }, [refresh]);

  const deleteRule = useCallback(async (id: string) => {
    try {
      const db = await getDatabase();
      await deleteSyncRuleRepo(db, id);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Failed to delete rule'));
      throw e;
    }
  }, [refresh]);

  const toggleRule = useCallback(async (id: string, isEnabled: boolean) => {
    try {
      const db = await getDatabase();
      await toggleSyncRuleEnabled(db, id, isEnabled);
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Failed to toggle rule'));
      throw e;
    }
  }, [refresh]);

  return { rules, loading, error, refresh, toggleRule, deleteRule, addRule };
}
