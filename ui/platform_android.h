#ifndef UI2_PLATFORM_ANDROID_H
#define UI2_PLATFORM_ANDROID_H

#include <jni.h>
#include <android/native_activity.h>

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
static int ui2_android_open_url(void *activity, const char *url) {
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
	if (act == NULL || url == NULL || url[0] == 0) return 0;
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
	target = (*env)->NewStringUTF(env, url);
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
static int ui2_android_share_text(void *activity, const char *text) {
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
	jstring extra_key;
	jobject intent;
	jobject chooser;
	if (act == NULL || text == NULL || text[0] == 0) return 0;
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
	body = (*env)->NewStringUTF(env, text);
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
