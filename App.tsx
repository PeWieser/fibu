import './global.css';
import React from 'react';
import { SafeAreaView, StyleSheet } from 'react-native';

import { ThemeProvider } from './src/theme/theme';
import { AppNavigator } from './src/navigation';

export default function App() {
  return (
    <ThemeProvider>
      <SafeAreaView style={styles.container}>
        <AppNavigator />
      </SafeAreaView>
    </ThemeProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
