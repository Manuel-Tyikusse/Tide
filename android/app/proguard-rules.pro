# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Regras para Supabase e suas dependências de rede.

# Supabase
-keep class io.supabase.** { *; }
-keep interface io.supabase.** { *; }
-dontwarn io.supabase.**

# Gotrue (autenticação do Supabase)
-keep class io.github.jan.supabase.gotrue.** { *; }
-dontwarn io.github.jan.supabase.gotrue.**

# Postgrest (base de dados do Supabase)
-keep class io.github.jan.supabase.postgrest.** { *; }
-dontwarn io.github.jan.supabase.postgrest.**

# Kotlin Coroutines & Serialization
-keep class kotlin.coroutines.jvm.internal.SuspendLambda { *; }
-dontwarn kotlin.coroutines.jvm.internal.SuspendLambda
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**

# OkHttp (a biblioteca de rede usada pelo Supabase)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Okio (dependência do OkHttp)
-keep class okio.** { *; }
-keep interface okio.** { *; }
-dontwarn okio.**
