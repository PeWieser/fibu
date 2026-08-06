import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import type { CompositeNavigationProp, RouteProp } from '@react-navigation/native';

export type RootStackParamList = {
  Onboarding: undefined;
  Main: { screen?: keyof MainTabParamList } | undefined;
  Settings: undefined;
  RemoteDetail: { remoteId: string };
};

export type MainTabParamList = {
  Dashboard: undefined;
  CloudDrives: undefined;
  SyncRules: undefined;
  JobHistory: undefined;
};

export type MainTabNavigationProp<T extends keyof MainTabParamList> = CompositeNavigationProp<
  BottomTabNavigationProp<MainTabParamList, T>,
  NativeStackNavigationProp<RootStackParamList>
>;

export type RootStackScreenProps<T extends keyof RootStackParamList> = {
  navigation: NativeStackNavigationProp<RootStackParamList, T>;
  route: RouteProp<RootStackParamList, T>;
};

export type MainTabScreenProps<T extends keyof MainTabParamList> = {
  navigation: MainTabNavigationProp<T>;
  route: RouteProp<MainTabParamList, T>;
};
