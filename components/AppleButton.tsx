import React, { useRef } from 'react';
import { View, Text, StyleSheet, TouchableWithoutFeedback, Animated, ActivityIndicator, TouchableOpacityProps } from 'react-native';
import LiquidGlassView from './NativeLiquidGlass';

interface AppleButtonProps extends TouchableOpacityProps {
  title: string;
  variant?: 'primary' | 'secondary' | 'destructive' | 'success';
  loading?: boolean;
}

export default function AppleButton({ 
  title, 
  variant = 'primary', 
  loading = false,
  style, 
  disabled,
  onPress,
  ...props 
}: AppleButtonProps) {
  
  // Drives the physical HIG "squish" depth interpolation
  const scale = useRef(new Animated.Value(1)).current;

  const handlePressIn = () => {
    if (disabled || loading) return;
    Animated.spring(scale, {
      toValue: 0.96, // Apple standard highlight depth
      tension: 100,
      friction: 5,
      useNativeDriver: true, // Offload to UI thread
    }).start();
  };

  const handlePressOut = () => {
    if (disabled || loading) return;
    Animated.spring(scale, {
      toValue: 1, // Apple bounce-back physics
      tension: 100,
      friction: 5,
      useNativeDriver: true,
    }).start();
  };

  const getTintColor = () => {
    if (disabled && !loading) return 'rgba(156, 163, 175, 0.2)'; // Gray
    switch (variant) {
      // Dropping specific tint opacity down to ~4-8% specifically so the raw Swift ultraThinMaterial 
      // accurately reflects exactly what is sitting underneath the button!
      case 'primary': return 'rgba(0, 122, 255, 0.08)'; // Deep Liquid Blue 
      case 'secondary': return 'rgba(142, 142, 147, 0.08)'; // Liquid Gray
      case 'destructive': return 'rgba(255, 59, 48, 0.06)'; // Apple Red
      case 'success': return 'rgba(52, 199, 89, 0.08)'; // Apple Green
    }
  };

  const getTextColor = () => {
    if (disabled && !loading) return '#9CA3AF'; // Gray text
    switch (variant) {
      case 'primary': return '#007AFF';
      case 'secondary': return '#4B5563'; 
      case 'destructive': return '#FF3B30';
      case 'success': return '#34C759';
    }
  };

  return (
    <TouchableWithoutFeedback 
      onPress={onPress} 
      onPressIn={handlePressIn} 
      onPressOut={handlePressOut}
      disabled={disabled || loading}
      {...props}
    >
      <Animated.View style={[styles.container, style, { transform: [{ scale }] }]}>
        {/* 1. Base Layer: The Native Liquid Glass Physics (Blurs background) */}
        <LiquidGlassView style={StyleSheet.absoluteFill} />
        
        {/* 2. Tint Layer: Apple HIG states the color tint must sit ON TOP of the glass */}
        <View style={[StyleSheet.absoluteFill, { backgroundColor: getTintColor() }]} />
        
        {/* 3. Interactive Layer */}
        <View style={styles.touchable}>
          {loading ? (
            <ActivityIndicator color={getTextColor()} />
          ) : (
            <Text style={[styles.text, { color: getTextColor() }]}>
              {title}
            </Text>
          )}
        </View>
      </Animated.View>
    </TouchableWithoutFeedback>
  );
}

const styles = StyleSheet.create({
  container: {
    // Apple HIG: buttons should use capsule shape. Hit region 44x44 minimum.
    height: 56,
    borderRadius: 28, // Perfect capsule
    overflow: 'hidden', // Clips the Liquid Glass and Tint to the capsule shape
    width: '100%',
  },
  touchable: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  text: {
    fontSize: 17, // iOS Standard Action Font Size
    fontWeight: '600', // Semibold is Apple's standard for primary buttons
    letterSpacing: -0.4,
  }
});
