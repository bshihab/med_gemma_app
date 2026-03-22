import { HealthMetricsJSON } from './healthIntegration';
import { initLlama, LlamaContext } from 'llama.rn';
import { Platform } from 'react-native';
import Constants from 'expo-constants';
import AsyncStorage from '@react-native-async-storage/async-storage';

export class InferenceEngine {
  private static llamaContext: LlamaContext | null = null;
  private static isModelLoaded = false;

  public static getIsModelLoaded(): boolean {
    return this.isModelLoaded;
  }

  /**
   * Initializes the llama.rn native bridge.
   * Loads the massive ~2.5GB Med-O-Gemma 4B quantized .gguf weights off the storage into iOS memory.
   * 
   * Note: In Expo Go, native C++ memory allocation for 2.5GB models is not possible.
   * This gracefully falls back to a simulated load for UI testing.
   */
  static async initializeModel(onProgress?: (progress: number) => void): Promise<boolean> {
    const isExpoGo = Constants.appOwnership === 'expo';

    if (isExpoGo || Platform.OS !== 'ios') {
      console.log("[llama.rn] Warning: Native AI can only run in a compiled iOS app. Simulating 3-second download.");

      return new Promise((resolve) => {
        let currentProgress = 0;
        const interval = setInterval(() => {
          currentProgress += 15;
          if (currentProgress > 100) currentProgress = 100;

          if (onProgress) onProgress(currentProgress);

          if (currentProgress >= 100) {
            clearInterval(interval);
            this.isModelLoaded = true;
            resolve(true);
          }
        }, 400); // Gradual simulated load for Expo Go testing
      });
    }

    try {
      console.log("[llama.rn] Initializing MedGemma 4B on Metal NPU...");

      // Native iOS Native Module loading
      // (The C++ bridge is computationally synchronous, so we simulate frontend progress while it locks the thread)
      if (onProgress) onProgress(10);
      let simProgress = 10;
      const simInterval = setInterval(() => {
        if (simProgress < 90) {
          simProgress += 10;
          if (onProgress) onProgress(simProgress);
        }
      }, 500);

      // Loads the model directly from the iOS app bundle using `is_model_asset`
      this.llamaContext = await initLlama({
        model: 'medgemma-4b-it_Q4_K_M.gguf',
        is_model_asset: true, // EXTREMELY IMPORTANT: Tells iOS to search the compiled app bundle for the file
        // @ts-ignore: Fusing the Vision Projector architecture (MedGemma mmproj) into the LLM logic layer
        mmproj: 'mmproj-medgemma-4b-it-F16.gguf',
        is_mmproj_asset: true,
        use_mlock: true, // Lock memory so iOS doesn't page it to disk
        n_ctx: 2048,     // Context window size
        n_gpu_layers: 99 // Offload all layers to Apple Metal GPU
      });

      clearInterval(simInterval);
      if (onProgress) onProgress(100);

      this.isModelLoaded = true;
      console.log("[llama.rn] MedGemma loaded successfully into Metal!");
      return true;
    } catch (e) {
      console.error("[llama.rn] Failed to load model. Is it in the Xcode bundle?", e);
      return false;
    }
  }

  /**
   * Executes the multimodal inference using the native llama.cpp bindings.
   * Fully offline and on-device.
   */
  static async translateLabReport(extractedText: string, healthJSON: HealthMetricsJSON, mode: 'lab' | 'weekly' = 'lab'): Promise<string> {
    if (!this.isModelLoaded) {
      throw new Error("Med-Gemma model is not loaded into memory yet.");
    }

    const isExpoGo = Constants.appOwnership === 'expo';
    if (isExpoGo || Platform.OS !== 'ios' || !this.llamaContext) {
      console.log("[llama.rn] Simulated inference (Expo Go fallback)...");
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve(`I checked your Apple Health data for this week, and I can see you've been getting great sleep (around ${healthJSON.avg_sleep_hours_last_30_days ?? 7.5} hours) and your resting heart rate is very healthy (${healthJSON.avg_resting_hr_last_30_days ?? 60} bpm). Keep it up!`);
        }, 2000);
      });
    }

    // Fetch stored user profile data (Age, Sex, Conditions) from secure local storage
    let knownConditions = "None reported";
    try {
      const storedProfile = await AsyncStorage.getItem('@user_profile');
      if (storedProfile) {
        const profile = JSON.parse(storedProfile);
        knownConditions = profile.medicalConditions || "None reported";
      }
    } catch (e) { }

    const behaviorPrompt = mode === 'weekly'
      ? "The user is requesting their weekly health check-in review. Analyze their Apple Health data provided below, praise their good metrics, and gently notify them of any anomalies based on their medical history."
      : "The user just scanned a lab report. Explain the OCR text logically in very simple, reassuring terms to a patient with no medical background.";

    // Formatting the MedGemma prompt via HuggingFace standard Gemma instruct format
    const prompt = `<start_of_turn>user
You are an empathetic, highly trained medical assistant. 
${behaviorPrompt}

User's Personal Health Context:
- Known Medical Conditions: ${knownConditions}
- Resting HR (30-day avg): ${healthJSON.avg_resting_hr_last_30_days ?? 'Unknown'} bpm
- Sleep (30-day avg): ${healthJSON.avg_sleep_hours_last_30_days ?? 'Unknown'} hours
- HRV (30-day avg): ${healthJSON.avg_hrv_last_30_days ?? 'Unknown'} ms

IMPORTANT INSTRUCTION: If any of the personal health context metrics above are labeled "Unknown" or the user lacks wearable data, completely ignore them. Do NOT guess them, and do not mention that they are missing. In these cases, focus 100% of your explanation on the Lab Report OCR Text.

Lab Report OCR Text (Ignore if weekly review):
"${extractedText}"

Provide your gentle, highly personalized, reassuring translation below.<end_of_turn>
<start_of_turn>model
`;

    console.log("[llama.rn] Executing on-device LLM inference via Metal...");

    try {
      const result = await this.llamaContext.completion({
        prompt: prompt,
        n_predict: 256,   // Max tokens to generate
        temperature: 0.3, // Low temperature for factual medical data
        top_p: 0.9,
      });

      console.log("[llama.rn] Inference complete.");
      return result.text;
    } catch (e) {
      console.error("[llama.rn] Inference error:", e);
      return "An error occurred while analyzing the report locally on your NPU. Please try again.";
    }
  }

  /**
   * Hardware Multimodal Vision Endpoint
   * Extracts insight from a raw physical document using the Med-Gemma Vision Projector.
   */
  static async translateMultimodal(base64Image: string, healthJSON: HealthMetricsJSON): Promise<string> {
    if (!this.isModelLoaded) {
      throw new Error("Med-Gemma Vision architecture is not loaded into memory yet.");
    }

    const isExpoGo = Constants.appOwnership === 'expo';
    if (isExpoGo || Platform.OS !== 'ios' || !this.llamaContext) {
      console.log("[llama.rn] Simulated Vision inference (Expo Go fallback for base64 intercept)...");
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve("I have successfully analyzed the physical document using offline Vision AI. The chart indicates your Vitamin D levels are currently low (22 ng/mL), which is below the standard reference range. Everything else looks perfectly normal.");
        }, 2500);
      });
    }

    // Google Gemma-2-Vision Instruction Format
    const prompt = `<start_of_turn>user
Analyze this medical document carefully. [IMAGE]
Explain the clinical data logically in very simple, reassuring terms to a patient.
<end_of_turn>
<start_of_turn>model
`;

    console.log("[llama.rn] Executing raw on-device Multimodal Vision inference via Metal...");

    try {
      const result = await this.llamaContext.completion({
        prompt: prompt,
        // @ts-ignore: Passing raw base64 strictly to the vision encoder bindings
        image_url: `data:image/jpeg;base64,${base64Image}`,
        n_predict: 256,
        temperature: 0.2,
        top_p: 0.9,
      });

      console.log("[llama.rn] Vision inference deeply completed.");
      return result.text;
    } catch (e) {
      console.error("[llama.rn] Vision inference error:", e);
      return "An error occurred while analyzing the image locally on your NPU. Please try again.";
    }
  }
}
