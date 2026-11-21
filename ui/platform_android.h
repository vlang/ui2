#ifndef UI2_PLATFORM_ANDROID_H
#define UI2_PLATFORM_ANDROID_H

#include <jni.h>
#include <android/native_activity.h>
#include <stdlib.h>

// The Android integrations below call platform Java APIs through JNI only, so
// no activity subclass or Java code is needed on the app side. The activity is
// a NativeActivity, which is a Context, so getSystemService and startActivity
// resolve on its own class. Calls arrive from the render thread, which is not
// attached to the JVM, so each helper attaches for the call.

static int ui2_android_jni_env(ANativeActivity *act, JNIEnv **env, int *attached) {
	JavaVM *vm;
	JNIEnv *result = NULL;
	int is_attached = 0;
	if (act == NULL || env == NULL || attached == NULL) return 0;
	vm = act->vm;
	if ((*vm)->GetEnv(vm, (void **)&result, JNI_VERSION_1_6) != JNI_OK) {
		if ((*vm)->AttachCurrentThread(vm, &result, NULL) != JNI_OK) return 0;
		is_attached = 1;
	}
	*env = result;
	*attached = is_attached;
	return 1;
}

static void ui2_android_jni_release(ANativeActivity *act, int attached) {
	if (attached && act != NULL) (*act->vm)->DetachCurrentThread(act->vm);
}

// V strings are ordinary UTF-8, but JNI's NewStringUTF expects modified UTF-8:
// 4-byte (non-BMP) sequences are invalid there (they can corrupt the string or
// abort under CheckJNI), and embedded NULs are cut off at the C string boundary.
// Decode the bytes to UTF-16 ourselves and use NewString with an explicit
// length, so emoji become correct surrogate pairs and embedded NULs survive.
// The caller must pass an explicit byte length; NUL termination is not assumed.
// Returns NULL if the pointer/length is invalid or if allocation/NewString
// fails (NewString may leave a pending exception for the caller to clear).
static jstring ui2_android_jstring_from_utf8(JNIEnv *env, const char *bytes, int len) {
	const unsigned char *p = (const unsigned char *)bytes;
	int i = 0;
	int units = 0;
	jchar *buf;
	jstring result;

	if (bytes == NULL || len <= 0) return NULL;

	// First pass: count UTF-16 code units (non-BMP needs a surrogate pair).
	while (i < len) {
		unsigned char c = p[i];
		if (c < 0x80) {
			i += 1;
			units += 1;
		} else if ((c & 0xE0) == 0xC0 && i + 1 < len) {
			i += 2;
			units += 1;
		} else if ((c & 0xF0) == 0xE0 && i + 2 < len) {
			i += 3;
			units += 1;
		} else if ((c & 0xF8) == 0xF0 && i + 3 < len) {
			i += 4;
			units += 2;
		} else {
			i += 1; // malformed byte -> U+FFFD
			units += 1;
		}
	}

	buf = (jchar *)malloc((size_t)units * sizeof(jchar));
	if (buf == NULL) return NULL;

	// Second pass: decode into UTF-16.
	i = 0;
	units = 0;
	while (i < len) {
		unsigned char c = p[i];
		if (c < 0x80) {
			buf[units++] = (jchar)c;
			i += 1;
		} else if ((c & 0xE0) == 0xC0 && i + 1 < len) {
			buf[units++] = (jchar)(((c & 0x1F) << 6) | (p[i + 1] & 0x3F));
			i += 2;
		} else if ((c & 0xF0) == 0xE0 && i + 2 < len) {
			buf[units++] = (jchar)(((c & 0x0F) << 12) | ((p[i + 1] & 0x3F) << 6) | (p[i + 2] & 0x3F));
			i += 3;
		} else if ((c & 0xF8) == 0xF0 && i + 3 < len) {
			unsigned int cp = ((unsigned int)(c & 0x07) << 18)
				| ((unsigned int)(p[i + 1] & 0x3F) << 12)
				| ((unsigned int)(p[i + 2] & 0x3F) << 6)
				| (unsigned int)(p[i + 3] & 0x3F);
			i += 4;
			if (cp > 0x10FFFF) {
				buf[units++] = (jchar)0xFFFD;
			} else {
				cp -= 0x10000;
				buf[units++] = (jchar)(0xD800 + (cp >> 10));
				buf[units++] = (jchar)(0xDC00 + (cp & 0x3FF));
			}
		} else {
			buf[units++] = (jchar)0xFFFD;
			i += 1;
		}
	}

	result = (*env)->NewString(env, buf, (jsize)units);
	free(buf);
	return result;
}

// ui2_android_haptic fires the vibrator for duration_ms at amplitude (1-255).
// Android 8 and newer take a VibrationEffect; older releases take the raw
// duration. Returns 1 when the vibration was requested.
static int ui2_android_haptic(void *activity, int duration_ms, int amplitude) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0;
	int fired = 0;
	jclass activity_class;
	jmethodID get_service;
	jstring service_name;
	jobject vibrator;
	jclass vibrator_class;
	jclass version_class;
	jfieldID sdk_field;
	jint sdk = 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	activity_class = (*env)->GetObjectClass(env, act->clazz);
	get_service = (*env)->GetMethodID(env, activity_class, "getSystemService",
		"(Ljava/lang/String;)Ljava/lang/Object;");
	if (get_service == NULL) goto haptic_done;
	service_name = (*env)->NewStringUTF(env, "vibrator");
	vibrator = (*env)->CallObjectMethod(env, act->clazz, get_service, service_name);
	if (vibrator == NULL || (*env)->ExceptionCheck(env)) goto haptic_name;
	vibrator_class = (*env)->GetObjectClass(env, vibrator);
	version_class = (*env)->FindClass(env, "android/os/Build$VERSION");
	if (version_class != NULL) {
		sdk_field = (*env)->GetStaticFieldID(env, version_class, "SDK_INT", "I");
		if (sdk_field != NULL) sdk = (*env)->GetStaticIntField(env, version_class, sdk_field);
		(*env)->DeleteLocalRef(env, version_class);
	}
	if ((*env)->ExceptionCheck(env)) {
		(*env)->ExceptionClear(env);
	} else if (sdk >= 26) {
		jclass effect_class = (*env)->FindClass(env, "android/os/VibrationEffect");
		if (effect_class != NULL) {
			jmethodID create = (*env)->GetStaticMethodID(env, effect_class, "createOneShot",
				"(JI)Landroid/os/VibrationEffect;");
			jmethodID vibrate_effect = (*env)->GetMethodID(env, vibrator_class, "vibrate",
				"(Landroid/os/VibrationEffect;)V");
			if (create != NULL && vibrate_effect != NULL) {
				jobject effect = (*env)->CallStaticObjectMethod(env, effect_class, create,
					(jlong)duration_ms, (jint)amplitude);
				if (effect != NULL && !(*env)->ExceptionCheck(env)) {
					(*env)->CallVoidMethod(env, vibrator, vibrate_effect, effect);
					fired = (*env)->ExceptionCheck(env) ? 0 : 1;
					(*env)->DeleteLocalRef(env, effect);
				}
			}
			(*env)->DeleteLocalRef(env, effect_class);
		}
		if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	} else {
		jmethodID vibrate = (*env)->GetMethodID(env, vibrator_class, "vibrate", "(J)V");
		if (vibrate != NULL) {
			(*env)->CallVoidMethod(env, vibrator, vibrate, (jlong)duration_ms);
			fired = (*env)->ExceptionCheck(env) ? 0 : 1;
		}
		if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	}
	(*env)->DeleteLocalRef(env, vibrator_class);
	(*env)->DeleteLocalRef(env, vibrator);
haptic_name:
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	(*env)->DeleteLocalRef(env, service_name);
haptic_done:
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	(*env)->DeleteLocalRef(env, activity_class);
	ui2_android_jni_release(act, attached);
	return fired;
}

// ui2_android_start_activity starts an intent from the activity. The call
// comes from the render thread, so FLAG_ACTIVITY_NEW_TASK carries it outside
// the activity's own task. Returns 1 when the intent was handed over.
static int ui2_android_start_activity(void *activity, jobject intent) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0;
	int started = 0;
	jclass activity_class;
	jmethodID start_activity;
	if (intent == NULL) return 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	activity_class = (*env)->GetObjectClass(env, act->clazz);
	start_activity = (*env)->GetMethodID(env, activity_class, "startActivity",
		"(Landroid/content/Intent;)V");
	if (start_activity != NULL) {
		(*env)->CallVoidMethod(env, act->clazz, start_activity, intent);
		started = (*env)->ExceptionCheck(env) ? 0 : 1;
	}
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	(*env)->DeleteLocalRef(env, activity_class);
	ui2_android_jni_release(act, attached);
	return started;
}

// ui2_android_open_url opens url with ACTION_VIEW. Returns 1 when the system
// took the intent.
static int ui2_android_open_url(void *activity, const char *url, int url_len) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0;
	int started = 0;
	jclass intent_class;
	jclass uri_class;
	jmethodID view_init;
	jmethodID parse;
	jmethodID add_flags;
	jstring action;
	jstring target;
	jobject uri;
	jobject intent;
	if (act == NULL || url == NULL || url_len <= 0) return 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	intent_class = (*env)->FindClass(env, "android/content/Intent");
	uri_class = (*env)->FindClass(env, "android/net/Uri");
	if (intent_class == NULL || uri_class == NULL) goto open_done;
	view_init = (*env)->GetMethodID(env, intent_class, "<init>",
		"(Ljava/lang/String;Landroid/net/Uri;)V");
	parse = (*env)->GetStaticMethodID(env, uri_class, "parse",
		"(Ljava/lang/String;)Landroid/net/Uri;");
	add_flags = (*env)->GetMethodID(env, intent_class, "addFlags",
		"(I)Landroid/content/Intent;");
	if (view_init == NULL || parse == NULL || add_flags == NULL) goto open_done;
	action = (*env)->NewStringUTF(env, "android.intent.action.VIEW");
	target = ui2_android_jstring_from_utf8(env, url, url_len);
	if (target == NULL) goto open_strings;
	uri = (*env)->CallStaticObjectMethod(env, uri_class, parse, target);
	if (uri == NULL || (*env)->ExceptionCheck(env)) goto open_strings;
	intent = (*env)->NewObject(env, intent_class, view_init, action, uri);
	if (intent == NULL || (*env)->ExceptionCheck(env)) goto open_uri;
	(*env)->CallObjectMethod(env, intent, add_flags, (jint)0x10000000);
	if ((*env)->ExceptionCheck(env)) goto open_intent;
	started = ui2_android_start_activity(activity, intent);
open_intent:
	(*env)->DeleteLocalRef(env, intent);
open_uri:
	(*env)->DeleteLocalRef(env, uri);
open_strings:
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	(*env)->DeleteLocalRef(env, action);
	(*env)->DeleteLocalRef(env, target);
open_done:
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	if (intent_class != NULL) (*env)->DeleteLocalRef(env, intent_class);
	if (uri_class != NULL) (*env)->DeleteLocalRef(env, uri_class);
	ui2_android_jni_release(act, attached);
	return started;
}

// ui2_android_share_text shares text with ACTION_SEND through the system
// chooser. Returns 1 when the system took the intent.
static int ui2_android_share_text(void *activity, const char *text, int text_len) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0;
	int started = 0;
	jclass intent_class;
	jmethodID send_init;
	jmethodID set_type;
	jmethodID put_extra;
	jmethodID add_flags;
	jmethodID create_chooser;
	jfieldID extra_text_field;
	jstring action;
	jstring mime;
	jstring body;
	// Initialized so the share_strings cleanup is safe if body creation fails.
	jstring extra_key = NULL;
	jobject intent;
	jobject chooser;
	if (act == NULL || text == NULL || text_len <= 0) return 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	intent_class = (*env)->FindClass(env, "android/content/Intent");
	if (intent_class == NULL) goto share_done;
	send_init = (*env)->GetMethodID(env, intent_class, "<init>", "(Ljava/lang/String;)V");
	set_type = (*env)->GetMethodID(env, intent_class, "setType",
		"(Ljava/lang/String;)Landroid/content/Intent;");
	put_extra = (*env)->GetMethodID(env, intent_class, "putExtra",
		"(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;");
	add_flags = (*env)->GetMethodID(env, intent_class, "addFlags",
		"(I)Landroid/content/Intent;");
	create_chooser = (*env)->GetStaticMethodID(env, intent_class, "createChooser",
		"(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;");
	extra_text_field = (*env)->GetStaticFieldID(env, intent_class, "EXTRA_TEXT",
		"Ljava/lang/String;");
	if (send_init == NULL || set_type == NULL || put_extra == NULL || add_flags == NULL
		|| create_chooser == NULL || extra_text_field == NULL) goto share_done;
	action = (*env)->NewStringUTF(env, "android.intent.action.SEND");
	mime = (*env)->NewStringUTF(env, "text/plain");
	body = ui2_android_jstring_from_utf8(env, text, text_len);
	if (body == NULL) goto share_strings;
	extra_key = (*env)->GetStaticObjectField(env, intent_class, extra_text_field);
	intent = (*env)->NewObject(env, intent_class, send_init, action);
	if (intent == NULL || (*env)->ExceptionCheck(env)) goto share_strings;
	(*env)->CallObjectMethod(env, intent, set_type, mime);
	(*env)->CallObjectMethod(env, intent, put_extra, extra_key, body);
	(*env)->CallObjectMethod(env, intent, add_flags, (jint)0x10000000);
	if ((*env)->ExceptionCheck(env)) goto share_intent;
	chooser = (*env)->CallStaticObjectMethod(env, intent_class, create_chooser, intent,
		(*env)->NewStringUTF(env, "Share"));
	if (chooser == NULL || (*env)->ExceptionCheck(env)) goto share_intent;
	started = ui2_android_start_activity(activity, chooser);
	(*env)->DeleteLocalRef(env, chooser);
share_intent:
	(*env)->DeleteLocalRef(env, intent);
share_strings:
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	(*env)->DeleteLocalRef(env, action);
	(*env)->DeleteLocalRef(env, mime);
	(*env)->DeleteLocalRef(env, body);
	(*env)->DeleteLocalRef(env, extra_key);
share_done:
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	if (intent_class != NULL) (*env)->DeleteLocalRef(env, intent_class);
	ui2_android_jni_release(act, attached);
	return started;
}

#endif
