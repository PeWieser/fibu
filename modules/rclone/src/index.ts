/**
 * index.ts — Public entry point for the `modules/rclone` Expo local module.
 *
 * Consumers import from this file (or from `modules/rclone/src`) and receive
 * the full typed surface of the rclone bridge.
 */

export * from './RcloneTypes';
export * from './RcloneNativeModule';
export { RcloneService } from './RcloneService';
export type { EventSubscription } from './RcloneService';
