import React, { useEffect, useState } from 'react';
import { View, ActivityIndicator } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useTheme } from '../theme/theme';
import { MainTabs } from './MainTabs';
import { OnboardingScreen, SettingsScreen, RemoteDetailScreen, AddRemoteScreen } from '../screens';
import type { RootStackParamList } from './types';
import { StatusBar } from 'expo-status-bar';
import { hasCompletedOnboarding } from '../utils/onboarding';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function AppNavigator() {
  const { colors, colorScheme } = useTheme();
  const [initialRoute, setInitialRoute] = useState<keyof RootStackParamList | null>(null);

  useEffect(() => {
    hasCompletedOnboarding()
      .then((done) => setInitialRoute(done ? 'Main' : 'Onboarding'))
      .catch(() => setInitialRoute('Onboarding'));
  }, []);

  if (!initialRoute) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: colors.bg.canvas }}>
        <ActivityIndicator size="large" color={colors.accent.default} />
      </View>
    );
  }

  return (
    <NavigationContainer>
      <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
      <Stack.Navigator
        initialRouteName={initialRoute}
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: colors.bg.canvas },
        }}
      >
        <Stack.Screen name="Onboarding" component={OnboardingScreen} />
        <Stack.Screen name="Main" component={MainTabs} />

        {/* Modals */}
        <Stack.Group screenOptions={{ presentation: 'modal', headerShown: true }}>
          <Stack.Screen
            name="Settings"
            component={SettingsScreen}
            options={{ title: 'Settings' }}
          />
          <Stack.Screen
            name="RemoteDetail"
            component={RemoteDetailScreen}
            options={{ title: 'Remote Details' }}
          />
          <Stack.Screen
            name="AddRemote"
            component={AddRemoteScreen}
            options={{ title: 'Add Drive' }}
          />
        </Stack.Group>
      </Stack.Navigator>
    </NavigationContainer>
  );
}
