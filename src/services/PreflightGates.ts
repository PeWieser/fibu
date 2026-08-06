import * as Network from 'expo-network';
import * as Battery from 'expo-battery';
import type { SyncRule } from '../types';

export class PreflightGates {
  static async checkWifi(): Promise<boolean> {
    const state = await Network.getNetworkStateAsync();
    return state.isConnected === true && state.type === Network.NetworkStateType.WIFI;
  }

  static async checkBattery(): Promise<{ level: number; isCharging: boolean }> {
    const level = await Battery.getBatteryLevelAsync();
    const powerState = await Battery.getPowerStateAsync();
    
    const isCharging = 
      powerState.batteryState === Battery.BatteryState.CHARGING || 
      powerState.batteryState === Battery.BatteryState.FULL;
      
    return { level, isCharging };
  }

  static async canRunRule(rule: SyncRule): Promise<{ canRun: boolean; reason?: string }> {
    if (!rule.is_enabled) {
      return { canRun: false, reason: 'Rule is disabled' };
    }

    if (rule.requires_wifi) {
      const isWifi = await this.checkWifi();
      if (!isWifi) {
        return { canRun: false, reason: 'WiFi is required' };
      }
    }

    if (rule.requires_charging) {
      const battery = await this.checkBattery();
      if (!battery.isCharging) {
        return { canRun: false, reason: 'Charging is required' };
      }
    }

    return { canRun: true };
  }
}
