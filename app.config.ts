import { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'EchoVault',
  slug: 'echovault',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  userInterfaceStyle: 'automatic',
  ios: {
    supportsTablet: true,
    bundleIdentifier: 'com.echovault.app',
    infoPlist: {
      NSPhotoLibraryUsageDescription:
        'EchoVault needs access to your photo library to back up photos and videos to your connected cloud storage.',
      NSPhotoLibraryAddUsageDescription:
        'EchoVault needs permission to save restored media to your photo library.',
      UIBackgroundModes: ['fetch', 'processing']
    }
  },
  android: {
    package: 'com.echovault.app',
    adaptiveIcon: {
      backgroundColor: '#0F172A',
      foregroundImage: './assets/android-icon-foreground.png',
      backgroundImage: './assets/android-icon-background.png',
      monochromeImage: './assets/android-icon-monochrome.png'
    },
    permissions: [
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'FOREGROUND_SERVICE',
      'RECEIVE_BOOT_COMPLETED',
      'ACCESS_NETWORK_STATE',
      'WAKE_LOCK'
    ]
  },
  web: {
    favicon: './assets/favicon.png'
  },
  plugins: [
    [
      'expo-media-library',
      {
        photosPermission: 'EchoVault needs access to your photos to perform backups.',
        savePhotosPermission: 'EchoVault needs permission to restore photos to your device.'
      }
    ]
  ]
});
