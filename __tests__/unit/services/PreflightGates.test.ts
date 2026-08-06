import * as Network from 'expo-network';
import * as Battery from 'expo-battery';
import { PreflightGates } from '../../../src/services/PreflightGates';
import type { SyncRule } from '../../../src/types';

jest.mock('expo-network', () => ({
  getNetworkStateAsync: jest.fn(),
  NetworkStateType: { WIFI: 'WIFI', CELLULAR: 'CELLULAR', NONE: 'NONE' }
}));

jest.mock('expo-battery', () => ({
  getBatteryLevelAsync: jest.fn(),
  getPowerStateAsync: jest.fn(),
  BatteryState: { UNKNOWN: 0, UNPLUGGED: 1, CHARGING: 2, FULL: 3 }
}));

const mockNetwork = Network as jest.Mocked<typeof Network>;
const mockBattery = Battery as jest.Mocked<typeof Battery>;

describe('PreflightGates', () => {
  const createRule = (overrides?: Partial<SyncRule>): SyncRule => ({
    id: 'test-rule',
    source_album_id: 'album-1',
    media_type: 'BOTH',
    target_remote_id: 'remote-1',
    sync_mode: 'ECHO',
    requires_wifi: false,
    requires_charging: false,
    is_enabled: true,
    created_at: '2026-08-01T00:00:00Z',
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockNetwork.getNetworkStateAsync.mockResolvedValue({
      isConnected: true,
      type: Network.NetworkStateType.WIFI,
      isInternetReachable: true,
    });
    mockBattery.getBatteryLevelAsync.mockResolvedValue(1.0);
    mockBattery.getPowerStateAsync.mockResolvedValue({
      batteryState: Battery.BatteryState.CHARGING,
      batteryLevel: 1.0,
      lowPowerMode: false,
    });
  });

  it('rejects disabled rules', async () => {
    const rule = createRule({ is_enabled: false });
    const res = await PreflightGates.canRunRule(rule);
    expect(res.canRun).toBe(false);
    expect(res.reason).toBe('Rule is disabled');
  });

  it('allows if everything is ok', async () => {
    const rule = createRule({ requires_wifi: true, requires_charging: true });
    const res = await PreflightGates.canRunRule(rule);
    expect(res.canRun).toBe(true);
  });

  it('rejects if wifi required but not on wifi', async () => {
    mockNetwork.getNetworkStateAsync.mockResolvedValue({
      isConnected: true,
      type: Network.NetworkStateType.CELLULAR,
      isInternetReachable: true,
    });
    const rule = createRule({ requires_wifi: true });
    const res = await PreflightGates.canRunRule(rule);
    expect(res.canRun).toBe(false);
    expect(res.reason).toBe('WiFi is required');
  });

  it('rejects if charging required but unplugged', async () => {
    mockBattery.getPowerStateAsync.mockResolvedValue({
      batteryState: Battery.BatteryState.UNPLUGGED,
      batteryLevel: 0.5,
      lowPowerMode: false,
    });
    const rule = createRule({ requires_charging: true });
    const res = await PreflightGates.canRunRule(rule);
    expect(res.canRun).toBe(false);
    expect(res.reason).toBe('Charging is required');
  });

  it('allows if charging required and battery is FULL', async () => {
    mockBattery.getPowerStateAsync.mockResolvedValue({
      batteryState: Battery.BatteryState.FULL,
      batteryLevel: 1.0,
      lowPowerMode: false,
    });
    const rule = createRule({ requires_charging: true });
    const res = await PreflightGates.canRunRule(rule);
    expect(res.canRun).toBe(true);
  });
});
