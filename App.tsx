import './global.css';
import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View, useColorScheme } from 'react-native';

export default function App() {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';

  return (
    <View style={[styles.container, isDark ? styles.darkBg : styles.lightBg]}>
      <StatusBar style={isDark ? 'light' : 'dark'} />
      <View style={styles.badge}>
        <Text style={styles.badgeText}>PHASE 0 — FOUNDATION</Text>
      </View>
      <Text style={[styles.title, isDark ? styles.darkText : styles.lightText]}>
        EchoVault
      </Text>
      <Text style={[styles.subtitle, isDark ? styles.darkSubtext : styles.lightSubtext]}>
        Professional Cross-Platform Backup Engine
      </Text>
      <View style={[styles.card, isDark ? styles.darkCard : styles.lightCard]}>
        <Text style={[styles.cardTitle, isDark ? styles.darkText : styles.lightText]}>
          System Ready
        </Text>
        <Text style={[styles.cardDetail, isDark ? styles.darkSubtext : styles.lightSubtext]}>
          TypeScript strict • NativeWind v4 • RcloneModule bridge stub
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24
  },
  lightBg: {
    backgroundColor: '#F8FAFC'
  },
  darkBg: {
    backgroundColor: '#090D16'
  },
  badge: {
    backgroundColor: '#3B82F61A',
    borderColor: '#3B82F6',
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 6,
    marginBottom: 16
  },
  badgeText: {
    color: '#3B82F6',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.5
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    letterSpacing: -0.5,
    marginBottom: 4
  },
  subtitle: {
    fontSize: 14,
    marginBottom: 32,
    textAlign: 'center'
  },
  lightText: {
    color: '#0F172A'
  },
  darkText: {
    color: '#F8FAFC'
  },
  lightSubtext: {
    color: '#64748B'
  },
  darkSubtext: {
    color: '#94A3B8'
  },
  card: {
    width: '100%',
    padding: 16,
    borderRadius: 12,
    borderWidth: 1
  },
  lightCard: {
    backgroundColor: '#FFFFFF',
    borderColor: '#E2E8F0'
  },
  darkCard: {
    backgroundColor: '#131C2E',
    borderColor: '#1E293B'
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4
  },
  cardDetail: {
    fontSize: 13
  }
});
