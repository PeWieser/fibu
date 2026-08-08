import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useTheme } from '../theme/theme';
import { MainTabs } from './MainTabs';
import { OnboardingScreen, SettingsScreen, RemoteDetailScreen } from '../screens';
import type { RootStackParamList } from './types';
import { StatusBar } from 'expo-status-bar';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function AppNavigator() {
  const { colors, colorScheme } = useTheme();

  return (
    <NavigationContainer>
      <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
      <Stack.Navigator
        initialRouteName="Onboarding" // Note: Will change based on DB state later
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
        </Stack.Group>
      </Stack.Navigator>
    </NavigationContainer>
  );
}
