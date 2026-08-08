# kotlinx.serialization keeps generated serializers on the companion of every
# @Serializable class; R8 cannot see those references through reflection.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**

-keepclassmembers class com.robesthud.tribesera.** {
    *** Companion;
}
-keepclasseswithmembers class com.robesthud.tribesera.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.robesthud.tribesera.**$$serializer { *; }
