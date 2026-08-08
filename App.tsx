import './global.css';
import React from 'react';
import { StyleSheet } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { ThemeProvider } from './src/theme/theme';
import { AppNavigator } from './src/navigation';

export default function App() {
  return (
    <ThemeProvider>
      <SafeAreaProvider style={styles.container}>
        <AppNavigator />
      </SafeAreaProvider>
    </ThemeProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
