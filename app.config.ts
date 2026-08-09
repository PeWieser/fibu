import { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'Fibu',
  slug: 'fibu',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  userInterfaceStyle: 'automatic',
  ios: {
    supportsTablet: true,
    bundleIdentifier: 'com.fibu.app',
    infoPlist: {
      NSPhotoLibraryUsageDescription:
        'Fibu needs access to your photo library to back up photos and videos to your connected cloud storage.',
      NSPhotoLibraryAddUsageDescription:
        'Fibu needs permission to save restored media to your photo library.',
      UIBackgroundModes: ['fetch'],
    },
  },
  android: {
    package: 'com.fibu.app',
    adaptiveIcon: {
      backgroundColor: '#0F172A',
      foregroundImage: './assets/android-icon-foreground.png',
      backgroundImage: './assets/android-icon-background.png',
      monochromeImage: './assets/android-icon-monochrome.png',
    },
  },
  web: {
    favicon: './assets/favicon.png',
  },
  plugins: [
    [
      'expo-media-library',
      {
        photosPermission: 'Fibu needs access to your photos to perform backups.',
        savePhotosPermission: 'Fibu needs permission to restore photos to your device.',
        granularPermissions: ['photo', 'video'],
      },
    ],
  ],
});
