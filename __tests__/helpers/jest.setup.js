jest.mock('expo-modules-core', () => {
  function EventEmitter() {
    this.addListener = jest.fn(() => ({ remove: jest.fn() }));
    this.removeListener = jest.fn();
    this.removeAllListeners = jest.fn();
  }
  return {
    __esModule: true,
    requireNativeModule: jest.fn(() => ({})),
    EventEmitter: EventEmitter,
  };
});

jest.mock('react-native-reanimated', () => {
  const React = require('react');
  const { View, Text, ScrollView } = require('react-native');
  return {
    __esModule: true,
    default: {
      View, Text, ScrollView,
      createAnimatedComponent: (Component) => Component,
    },
    useSharedValue: jest.fn((val) => ({ value: val })),
    useAnimatedStyle: jest.fn(() => ({})),
    withTiming: jest.fn((val) => val),
    withSpring: jest.fn((val) => val),
    interpolateColor: jest.fn(),
  };
});

jest.mock('expo/src/winter/fetch/FetchResponse', () => ({
  NativeResponse: jest.fn(),
}));

jest.mock('expo/src/winter/fetch/fetch', () => ({
  fetch: jest.fn(() => Promise.resolve({
    json: () => Promise.resolve({}),
    text: () => Promise.resolve(''),
    ok: true,
    status: 200,
  })),
  Request: jest.fn(),
  Response: jest.fn(),
  Headers: jest.fn(),
}));
