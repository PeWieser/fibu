import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useTheme } from '../theme/theme';
import { DashboardScreen, CloudDrivesScreen, SyncRulesScreen, JobHistoryScreen } from '../screens';
import type { MainTabParamList } from './types';
import { Home, Cloud, ListTree, Clock } from 'lucide-react-native';

const Tab = createBottomTabNavigator<MainTabParamList>();

export function MainTabs() {
  const { colors, typography } = useTheme();

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: true,
        headerStyle: { backgroundColor: colors.bg.canvas },
        headerTitleStyle: {
          color: colors.text.primary,
          fontSize: typography.lg.fontSize,
          fontWeight: '600',
        },
        headerShadowVisible: false,
        tabBarStyle: {
          backgroundColor: colors.bg.surface,
          borderTopColor: colors.border.subtle,
        },
        tabBarActiveTintColor: colors.accent.default,
        tabBarInactiveTintColor: colors.text.muted,
        tabBarLabelStyle: {
          fontSize: 12,
        },
      }}
    >
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{
          title: 'Dashboard',
          tabBarIcon: ({ color, size }) => <Home color={color} size={size} />,
        }}
      />
      <Tab.Screen
        name="CloudDrives"
        component={CloudDrivesScreen}
        options={{
          title: 'Cloud Drives',
          tabBarIcon: ({ color, size }) => <Cloud color={color} size={size} />,
        }}
      />
      <Tab.Screen
        name="SyncRules"
        component={SyncRulesScreen}
        options={{
          title: 'Rules',
          tabBarIcon: ({ color, size }) => <ListTree color={color} size={size} />,
        }}
      />
      <Tab.Screen
        name="JobHistory"
        component={JobHistoryScreen}
        options={{
          title: 'History',
          tabBarIcon: ({ color, size }) => <Clock color={color} size={size} />,
        }}
      />
    </Tab.Navigator>
  );
}
