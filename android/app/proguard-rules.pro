# Suppress warnings for ML Kit text language-specific recognizers not used
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# Suppress warnings for TFLite GPU delegate options (not bundled on Android here)
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# Keep ML Kit vision public APIs
-keep class com.google.mlkit.vision.** { *; }

# Keep TFLite public APIs
-keep class org.tensorflow.lite.** { *; }

