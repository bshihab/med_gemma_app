import { Platform } from 'react-native';
import Constants from 'expo-constants';

// Try to import Apple HealthKit. In many environments (Expo Go, Simulator),
// the module may load but the native functions inside will be undefined.
let AppleHealthKit: any = null;
try {
  const healthModule = require('react-native-health');
  const candidate = healthModule?.default || healthModule;
  // Only trust it if the critical function actually exists as a real function
  if (candidate && typeof candidate.initHealthKit === 'function') {
    AppleHealthKit = candidate;
  }
} catch (e) {
  // Module not installed or not linked — totally fine, we'll use mock data
}

// Format for our LLM to consume
export interface HealthMetricsJSON {
  avg_resting_hr_last_30_days: number | null;
  avg_sleep_hours_last_30_days: number | null;
  avg_hrv_last_30_days: number | null;
  is_mock_data?: boolean;
}

/** Returns mock health data for development/testing */
function getMockData(): HealthMetricsJSON {
  console.log("HealthKit unavailable. Returning local mock health data.");
  return {
    avg_resting_hr_last_30_days: 85,
    avg_sleep_hours_last_30_days: 7.2,
    avg_hrv_last_30_days: 45,
    is_mock_data: true
  };
}

export class HistoricalDataService {
  /**
   * Fetches health metrics from Apple HealthKit.
   * Gracefully falls back to mock data when running in:
   *   - Expo Go (sandbox blocks native modules)
   *   - iOS Simulator (no real HealthKit hardware)
   *   - Non-iOS devices (Android, Web)
   */
  static async getHealthMetrics(): Promise<HealthMetricsJSON> {
    return new Promise((resolve) => {
      // 1. If we are not on iOS, or running in Expo Go, use mock data immediately
      const isExpoGo = Constants.appOwnership === 'expo';
      if (Platform.OS !== 'ios' || isExpoGo) {
        return resolve(getMockData());
      }

      // 2. If the native HealthKit module failed to load (e.g. Simulator), use mock data
      if (!AppleHealthKit || !AppleHealthKit.initHealthKit) {
        return resolve(getMockData());
      }

      // 3. We are on a REAL iOS device with HealthKit available!
      const permissions = {
        permissions: {
          read: [
            AppleHealthKit.Constants.Permissions.RestingHeartRate,
            AppleHealthKit.Constants.Permissions.SleepAnalysis,
            AppleHealthKit.Constants.Permissions.HeartRateVariability,
          ],
          write: [],
        },
      };

      AppleHealthKit.initHealthKit(permissions, (err: string) => {
        if (err) {
          console.error('[error] Error initializing HealthKit: ', err);
          return resolve(getMockData());
        }

        let options = {
          startDate: (new Date(new Date().getTime() - (30 * 24 * 60 * 60 * 1000))).toISOString(),
        };

        AppleHealthKit.getRestingHeartRate(options, (err: string, results: any) => {
          if (err || !results) {
            console.log("No resting HR data found in Apple Health.", err);
            return resolve({ avg_resting_hr_last_30_days: null, avg_sleep_hours_last_30_days: null, avg_hrv_last_30_days: null });
          }

          let avgHR = 0;
          if (Array.isArray(results) && results.length > 0) {
            const sum = results.reduce((acc: number, curr: any) => acc + curr.value, 0);
            avgHR = Math.round(sum / results.length);
          } else if (results.value) {
            avgHR = Math.round(results.value);
          } else {
            return resolve({ avg_resting_hr_last_30_days: null, avg_sleep_hours_last_30_days: null, avg_hrv_last_30_days: null });
          }

          resolve({
            avg_resting_hr_last_30_days: avgHR,
            avg_sleep_hours_last_30_days: 7.5,
            avg_hrv_last_30_days: 48,
            is_mock_data: false
          });
        });
      });
    });
  }
}

