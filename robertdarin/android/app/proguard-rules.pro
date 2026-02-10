# ============================================
# PROGUARD RULES - Robert Darin Fintech
# Para Google Play Store
# VERSIÓN COMPLETA - Corrige crash al inicio
# ============================================

# ============================================
# FLUTTER CORE - NO TOCAR
# ============================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# ============================================
# SUPABASE - CRÍTICO PARA QUE NO CRASHEE
# ============================================
-keep class io.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions

# GoTrue (Auth de Supabase)
-keep class io.github.jan.supabase.gotrue.** { *; }
-keep class io.github.jan.supabase.postgrest.** { *; }
-keep class io.github.jan.supabase.realtime.** { *; }
-keep class io.github.jan.supabase.storage.** { *; }
-keep class io.github.jan.supabase.functions.** { *; }

# ============================================
# KTOR - USADO POR SUPABASE (MUY IMPORTANTE)
# ============================================
-keep class io.ktor.** { *; }
-keep class io.ktor.client.** { *; }
-keep class io.ktor.client.engine.** { *; }
-keep class io.ktor.client.engine.cio.** { *; }
-keep class io.ktor.client.engine.okhttp.** { *; }
-keep class io.ktor.client.plugins.** { *; }
-keep class io.ktor.http.** { *; }
-keep class io.ktor.serialization.** { *; }
-keep class io.ktor.util.** { *; }
-keep class io.ktor.websocket.** { *; }
-dontwarn io.ktor.**
-dontnote io.ktor.**

# ============================================
# KOTLIN - CRÍTICO
# ============================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Kotlin Serialization - MUY IMPORTANTE
-keepattributes RuntimeVisibleAnnotations
-keep class kotlinx.serialization.** { *; }
-keep class kotlinx.serialization.json.** { *; }
-keep class kotlinx.serialization.internal.** { *; }
-keepclassmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# ============================================
# OKHTTP / OKIO - Networking
# ============================================
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ============================================
# SLF4J / Logging
# ============================================
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# ============================================
# GSON
# ============================================
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.stream.** { *; }

# ============================================
# ANDROID CORE
# ============================================
-keep class androidx.** { *; }
-keep class android.** { *; }
-dontwarn androidx.**
-dontwarn android.**

# Provider / Lifecycle
-keep class androidx.lifecycle.** { *; }
-keep class androidx.datastore.** { *; }

# ============================================
# PLUGINS DE FLUTTER
# ============================================

# PDF y Printing
-keep class com.itextpdf.** { *; }
-dontwarn com.itextpdf.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ============================================
# GOOGLE PLAY CORE
# ============================================
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ============================================
# CRYPTO / SECURITY
# ============================================
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }
-keep class javax.net.ssl.** { *; }
-dontwarn javax.crypto.**
-dontwarn java.security.**

# ============================================
# INTL / DATE
# ============================================
-keep class com.ibm.icu.** { *; }
-dontwarn com.ibm.icu.**

# ============================================
# APP ESPECÍFICA
# ============================================
-keep class com.robertdarin.fintech.** { *; }

# Mantener modelos de datos (reflexión)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Mantener constructores públicos
-keepclassmembers class * {
    public <init>(...);
}

# Métodos nativos
-keepclasseswithmembernames class * {
    native <methods>;
}

# Enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ============================================
# REMOVER LOGS EN PRODUCCIÓN
# ============================================
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# ============================================
# REGLAS GENÉRICAS PARA EVITAR CRASHES
# ============================================
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Signature
-keepattributes Exceptions
-keepattributes *Annotation*

# Evitar warnings innecesarios
-dontwarn java.lang.invoke.**
-dontwarn sun.misc.**
-dontwarn javax.annotation.**