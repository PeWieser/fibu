import React, { useState, useCallback, useMemo } from 'react';
import {
  View,
  ScrollView,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { Text, Button } from '../components';
import type { RootStackScreenProps } from '../navigation/types';
import { useTheme } from '../theme/theme';
import { useCloudRemotes } from '../hooks/useCloudRemotes';
import {
  RCLONE_PROVIDERS,
  PROVIDER_CATEGORIES,
  filterProviders,
  type RcloneProvider,
  type RcloneCategory,
} from '../data/rcloneProviders';

export function AddRemoteScreen({ navigation }: RootStackScreenProps<'AddRemote'>) {
  const { colors, spacing, borderRadius: radius } = useTheme();
  const { addRemote } = useCloudRemotes();

  const [name, setName] = useState('');
  const [search, setSearch] = useState('');
  const [provider, setProvider] = useState<RcloneProvider>(RCLONE_PROVIDERS[0]);
  const [rcloneConfig, setRcloneConfig] = useState('');
  const [saving, setSaving] = useState(false);

  const filtered = useMemo(() => filterProviders(search), [search]);

  const grouped = useMemo(() => {
    const map = new Map<RcloneCategory, RcloneProvider[]>();
    for (const cat of PROVIDER_CATEGORIES) {
      const items = filtered.filter((p) => p.category === cat);
      if (items.length > 0) map.set(cat, items);
    }
    return map;
  }, [filtered]);

  const isValid = name.trim().length > 0 && rcloneConfig.trim().length > 0;

  const handleSave = useCallback(async () => {
    if (!isValid) return;
    setSaving(true);
    try {
      await addRemote({
        name: name.trim(),
        provider: provider.rcloneType,
        rclone_config: rcloneConfig.trim(),
        is_encrypted: false,
        total_space_bytes: 0,
        used_space_bytes: 0,
      });
      navigation.goBack();
    } catch (e) {
      Alert.alert('Error', e instanceof Error ? e.message : 'Failed to add drive.');
    } finally {
      setSaving(false);
    }
  }, [isValid, name, provider, rcloneConfig, addRemote, navigation]);

  const inputStyle = {
    backgroundColor: colors.bg.surface,
    borderColor: colors.border.default,
    color: colors.text.primary,
    borderRadius: radius.sm,
    borderWidth: 1,
    padding: spacing.md,
    fontSize: 15,
    minHeight: 48,
  };

  return (
    <ScrollView
      contentContainerStyle={[styles.container, { backgroundColor: colors.bg.canvas, padding: spacing.lg }]}
      keyboardShouldPersistTaps="handled"
    >
      {/* Name */}
      <View style={{ marginBottom: spacing.lg }}>
        <Text variant="sm" weight="semibold" style={{ marginBottom: spacing.xs }}>Name</Text>
        <TextInput
          accessibilityLabel="Drive name"
          placeholder="My Cloud Drive"
          placeholderTextColor={colors.text.muted}
          value={name}
          onChangeText={setName}
          style={inputStyle}
          autoFocus
          returnKeyType="next"
        />
      </View>

      {/* Provider picker */}
      <View style={{ marginBottom: spacing.lg }}>
        <Text variant="sm" weight="semibold" style={{ marginBottom: spacing.xs }}>Provider</Text>

        {/* Search bar */}
        <View style={[styles.searchRow, {
          backgroundColor: colors.bg.surface,
          borderColor: colors.border.default,
          borderRadius: radius.sm,
          marginBottom: spacing.sm,
        }]}>
          <TextInput
            accessibilityLabel="Search providers"
            accessibilityRole="search"
            placeholder="Search providers…"
            placeholderTextColor={colors.text.muted}
            value={search}
            onChangeText={setSearch}
            returnKeyType="search"
            clearButtonMode="while-editing"
            style={[styles.searchInput, { color: colors.text.primary, fontSize: 15 }]}
          />
        </View>

        {/* Selected pill */}
        <View style={[styles.selectedPill, {
          backgroundColor: colors.accent.muted,
          borderColor: colors.accent.default,
          borderRadius: radius.sm,
          padding: spacing.md,
          marginBottom: spacing.sm,
        }]}>
          <Text variant="xs" color="muted">Selected</Text>
          <Text variant="base" weight="semibold" color="accent">{provider.name}</Text>
          <Text variant="xs" color="muted">{provider.description}</Text>
        </View>

        {/* Grouped provider list */}
        {filtered.length === 0 ? (
          <Text variant="sm" color="muted" style={{ textAlign: 'center', paddingVertical: spacing.md }}>
            No providers found for "{search}"
          </Text>
        ) : (
          Array.from(grouped.entries()).map(([cat, providers]) => (
            <View key={cat} style={{ marginBottom: spacing.sm }}>
              <Text
                variant="xs"
                weight="semibold"
                color="muted"
                style={{ marginBottom: spacing.xs, textTransform: 'uppercase', letterSpacing: 0.8 }}
              >
                {cat}
              </Text>
              {providers.map((p) => {
                const selected = provider.id === p.id;
                return (
                  <TouchableOpacity
                    key={p.id}
                    accessibilityRole="radio"
                    accessibilityLabel={p.name}
                    accessibilityHint={p.description}
                    accessibilityState={{ selected }}
                    onPress={() => setProvider(p)}
                    style={[styles.providerRow, {
                      backgroundColor: selected ? colors.accent.muted : colors.bg.surface,
                      borderColor: selected ? colors.accent.default : colors.border.default,
                      borderRadius: radius.sm,
                      padding: spacing.md,
                      minHeight: 56,
                      marginBottom: spacing.xs,
                    }]}
                  >
                    <View style={{ flex: 1 }}>
                      <Text variant="base" weight={selected ? 'semibold' : 'normal'} color={selected ? 'accent' : 'primary'}>
                        {p.name}
                      </Text>
                      <Text variant="xs" color="muted">{p.description}</Text>
                    </View>
                    {p.requiresOAuth && (
                      <Text variant="xs" color="muted" style={{ marginLeft: spacing.xs }}>OAuth</Text>
                    )}
                  </TouchableOpacity>
                );
              })}
            </View>
          ))
        )}
      </View>

      {/* rclone config */}
      <View style={{ marginBottom: spacing.xl }}>
        <Text variant="sm" weight="semibold" style={{ marginBottom: spacing.xs }}>
          rclone Config (JSON)
        </Text>
        <TextInput
          accessibilityLabel="rclone config"
          placeholder={'{\n  "type": "' + provider.rcloneType + '",\n  ...\n}'}
          placeholderTextColor={colors.text.muted}
          value={rcloneConfig}
          onChangeText={setRcloneConfig}
          multiline
          numberOfLines={6}
          style={[inputStyle, { minHeight: 120, textAlignVertical: 'top', fontFamily: 'monospace' }]}
        />
        <Text variant="xs" color="muted" style={{ marginTop: spacing.xs }}>
          Paste the rclone backend config block as JSON.
          {provider.s3Provider ? ` Include "provider": "${provider.s3Provider}".` : ''}
        </Text>
      </View>

      <Button
        label={saving ? 'Saving…' : 'Add Drive'}
        variant="primary"
        fullWidth
        onPress={handleSave}
        disabled={!isValid || saving}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flexGrow: 1 },
  searchRow: { borderWidth: 1, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12 },
  searchInput: { flex: 1, height: 44 },
  selectedPill: { borderWidth: 1, gap: 2 },
  providerRow: { borderWidth: 1, flexDirection: 'row', alignItems: 'center' },
});
