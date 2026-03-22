import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, Switch, KeyboardAvoidingView, Platform, ScrollView, Dimensions } from 'react-native';
import { useRouter } from 'expo-router';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import AppleButton from '@/components/AppleButton';

const { height } = Dimensions.get('window');

export default function OnboardingScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [step, setStep] = useState(0);
  
  // Form State
  const [age, setAge] = useState('');
  const [sex, setSex] = useState('');
  const [conditions, setConditions] = useState('');
  const [agreed, setAgreed] = useState(false);

  const handleFinish = async () => {
    if (!agreed) return;
    
    const userProfile = {
      age,
      biologicalSex: sex,
      medicalConditions: conditions,
      onboardingComplete: true
    };
    
    await AsyncStorage.setItem('@user_profile', JSON.stringify(userProfile));
    
    // Once saved, navigate directly to the dashboard
    router.replace('/(tabs)');
  };

  const FeatureRow = ({ icon, title, subtitle }: { icon: keyof typeof Ionicons.glyphMap, title: string, subtitle: string }) => (
    <View className="flex-row items-start mb-8 w-full px-6">
      <View className="w-12 h-12 bg-apple-blue-light/10 dark:bg-apple-blue-dark/20 rounded-full items-center justify-center mr-4 mt-1">
        <Ionicons name={icon} size={24} color="#007AFF" />
      </View>
      <View className="flex-1">
        <Text className="text-[17px] font-semibold text-apple-text-light dark:text-apple-text-dark mb-1 tracking-tight">{title}</Text>
        <Text className="text-[15px] text-apple-text-secondary-light dark:text-apple-text-secondary-dark leading-[20px]">{subtitle}</Text>
      </View>
    </View>
  );

  return (
    <KeyboardAvoidingView 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-apple-background-light dark:bg-apple-background-dark"
    >
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'flex-start' }}>
        
        {/* STEP 0: HIG Welcome Screen */}
        {step === 0 && (
          <View className="flex-1 justify-between pb-12" style={{ paddingTop: insets.top + 20 }}>
            <View className="items-center w-full">
              <Text className="text-[34px] font-bold text-apple-text-light dark:text-apple-text-dark tracking-tight mb-16 text-center px-4">
                Welcome to{'\n'}Med-Gemma
              </Text>

              <FeatureRow 
                icon="shield-checkmark" 
                title="Total Privacy" 
                subtitle="Your medical data stays on your device. Zero clinical information is sent to the cloud by default." 
              />
              <FeatureRow 
                icon="flash" 
                title="On-Device Intelligence" 
                subtitle="Analyzes complex lab reports instantly using a locally running inference engine optimized for Apple Metal." 
              />
              <FeatureRow 
                icon="heart" 
                title="Health Integration" 
                subtitle="Cross-references your iPhone's vitals (HR, Sleep) against your paper lab reports." 
              />
            </View>

            <View className="px-6 mt-10">
              <AppleButton
                title="Continue"
                variant="primary"
                onPress={() => setStep(1)}
              />
            </View>
          </View>
        )}

        {/* STEP 1: Basic Intake */}
        {step === 1 && (
          <View className="w-full flex-1 px-6 pb-12 justify-between" style={{ paddingTop: insets.top + 30 }}>
            <View>
              <Text className="text-left text-[13px] font-semibold tracking-widest text-apple-text-secondary-light/50 dark:text-apple-text-secondary-dark/50 uppercase mb-2">Step 1 of 3</Text>
              <Text className="text-[34px] font-bold text-apple-text-light dark:text-apple-text-dark mb-8 tracking-tight">Basic Information</Text>
              
              <View className="mb-6">
                <Text className="text-apple-text-light dark:text-apple-text-dark font-medium text-[17px] mb-2">Age</Text>
                <TextInput 
                  className="bg-black/5 dark:bg-white/10 rounded-[12px] p-4 text-[17px] text-apple-text-light dark:text-apple-text-dark"
                  placeholder="e.g. 34"
                  placeholderTextColor="#9CA3AF"
                  keyboardType="numeric"
                  value={age}
                  onChangeText={setAge}
                />
              </View>

              <View className="mb-10">
                <Text className="text-apple-text-light dark:text-apple-text-dark font-medium text-[17px] mb-2">Biological Sex (for lab references)</Text>
                <View className="flex-row space-x-4">
                  {['Male', 'Female'].map((option) => (
                    <TouchableOpacity 
                      key={option}
                      className={`flex-1 py-4 rounded-[12px] items-center border ${sex === option ? 'border-apple-blue-light dark:border-apple-blue-dark bg-apple-blue-light/10 dark:bg-apple-blue-dark/20' : 'border-black/5 dark:border-white/10 bg-apple-card-light dark:bg-apple-card-dark'}`}
                      onPress={() => setSex(option)}
                    >
                      <Text className={`text-[17px] ${sex === option ? 'text-apple-blue-light dark:text-apple-blue-dark font-semibold' : 'text-apple-text-secondary-light dark:text-apple-text-secondary-dark font-medium'}`}>{option}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            </View>

            <AppleButton
              title="Continue"
              disabled={!age || !sex}
              onPress={() => setStep(2)}
            />
          </View>
        )}

        {/* STEP 2: Conditions */}
        {step === 2 && (
          <View className="w-full flex-1 px-6 pb-12 justify-between" style={{ paddingTop: insets.top + 30 }}>
            <View>
              <Text className="text-left text-[13px] font-semibold tracking-widest text-apple-text-secondary-light/50 dark:text-apple-text-secondary-dark/50 uppercase mb-2">Step 2 of 3</Text>
              <Text className="text-[34px] font-bold text-apple-text-light dark:text-apple-text-dark mb-4 tracking-tight">Medical Context</Text>
              <Text className="text-apple-text-secondary-light dark:text-apple-text-secondary-dark text-[17px] mb-8 leading-[22px]">
                Do you have any known medical conditions? This helps MedGemma tailor its explanations. (Leave blank if none).
              </Text>
              
              <View className="mb-10">
                <TextInput 
                  className="bg-black/5 dark:bg-white/10 rounded-[16px] p-4 text-[17px] text-apple-text-light dark:text-apple-text-dark h-32"
                  placeholder="e.g. Pre-diabetic, Hypothyroidism, Asthma..."
                  placeholderTextColor="#9CA3AF"
                  multiline
                  textAlignVertical="top"
                  value={conditions}
                  onChangeText={setConditions}
                />
              </View>
            </View>

            <View className="flex-row space-x-4 justify-between">
              <AppleButton
                title="Back"
                variant="secondary"
                style={{ width: 100 }}
                onPress={() => setStep(1)}
              />
              
              <View className="flex-1 ml-4">
                <AppleButton
                  title="Continue"
                  variant="primary"
                  onPress={() => setStep(3)}
                />
              </View>
            </View>
          </View>
        )}

        {/* STEP 3: Privacy & Safety */}
        {step === 3 && (
          <View className="w-full flex-1 px-6 pb-12 justify-between" style={{ paddingTop: insets.top + 30 }}>
            <View>
              <View className="w-16 h-16 bg-apple-red-light/10 dark:bg-apple-red-dark/20 rounded-full items-center justify-center mb-6">
                <Ionicons name="warning" size={32} color="#FF3B30" />
              </View>
              <Text className="text-[34px] font-bold text-apple-text-light dark:text-apple-text-dark mb-4 tracking-tight">Privacy & Safety</Text>
              
              <View className="bg-apple-card-light dark:bg-apple-card-dark p-6 rounded-[24px] shadow-sm border border-black/5 dark:border-white/10 mb-8">
                <Text className="text-apple-text-light dark:text-apple-text-dark font-medium mb-4 text-[15px] leading-[22px]">
                  1. <Text className="font-semibold text-apple-blue-light dark:text-apple-blue-dark">100% On-Device:</Text> MedGemma runs entirely on your phone's processor. Your sensitive health data and photos are NEVER sent to the cloud unless you explicitly turn on backups.
                </Text>
                <Text className="text-apple-text-light dark:text-apple-text-dark font-medium text-[15px] leading-[22px]">
                  2. <Text className="font-semibold text-apple-red-light dark:text-apple-red-dark">Not a Doctor:</Text> MedGemma is an experimental AI. It hallucinates. It is not a substitute for professional medical advice, diagnosis, or treatment.
                </Text>
              </View>
              
              <View className="flex-row items-center mb-10 px-2 justify-between">
                <Text className="text-apple-text-light dark:text-apple-text-dark font-semibold text-[17px] flex-1 mr-4">
                  I understand and agree to the terms above.
                </Text>
                <Switch 
                  value={agreed} 
                  onValueChange={setAgreed} 
                  trackColor={{ false: '#D1D5DB', true: '#34C759' }}
                />
              </View>
            </View>

            <AppleButton
              title="Complete Setup"
              disabled={!agreed}
              onPress={handleFinish}
            />
          </View>
        )}

      </ScrollView>
    </KeyboardAvoidingView>
  );
}
