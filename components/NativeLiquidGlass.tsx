import { Platform, View, requireNativeComponent } from 'react-native';

/**
 * Single source of truth for the native LiquidGlassView component.
 * requireNativeComponent must only be called ONCE per native view name,
 * so every file that needs <LiquidGlassView> should import from here.
 */
const LiquidGlassView = Platform.OS === 'ios'
  ? requireNativeComponent<any>('LiquidGlassView')
  : View;

export default LiquidGlassView;
