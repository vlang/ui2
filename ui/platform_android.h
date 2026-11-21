#ifndef UI2_PLATFORM_ANDROID_H
#define UI2_PLATFORM_ANDROID_H

#include <jni.h>
#include <android/native_activity.h>
#include <stdlib.h>

// Each request owns a local JNI frame, even when Sokol's render thread is
// already attached. Otherwise locals survive until that thread detaches.
static int ui2_android_jni_env(ANativeActivity *act, JNIEnv **env, int *attached) {
	JNIEnv *result = NULL;
	int rc;
	*attached = 0;
	if (act == NULL || act->vm == NULL || act->clazz == NULL) return 0;
	rc = (*act->vm)->GetEnv(act->vm, (void **)&result, JNI_VERSION_1_6);
	if (rc == JNI_EDETACHED) {
		if ((*act->vm)->AttachCurrentThread(act->vm, &result, NULL) != JNI_OK) return 0;
		*attached = 1;
	} else if (rc != JNI_OK) {
		return 0;
	}
	if ((*result)->PushLocalFrame(result, 32) != JNI_OK) {
		if ((*result)->ExceptionCheck(result)) (*result)->ExceptionClear(result);
		if (*attached) (*act->vm)->DetachCurrentThread(act->vm);
		return 0;
	}
	*env = result;
	return 1;
}

static void ui2_android_jni_release(ANativeActivity *act, JNIEnv *env, int attached) {
	if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
	(*env)->PopLocalFrame(env, NULL);
	if (attached) (*act->vm)->DetachCurrentThread(act->vm);
}

// JNI NewStringUTF consumes modified UTF-8, unlike V strings. Decode a sized
// UTF-8 buffer to UTF-16 so supplementary characters and NULs survive. Invalid
// sequences are rejected rather than turned into different characters/URLs.
static jstring ui2_android_jstring_from_utf8(JNIEnv *env, const char *bytes, int len) {
	const unsigned char *p = (const unsigned char *)bytes;
	int i = 0, units = 0;
	jchar *buf;
	jstring result;
	if (bytes == NULL || len <= 0) return NULL;
	// There are never more UTF-16 code units than UTF-8 bytes.
	buf = (jchar *)malloc((size_t)len * sizeof(jchar));
	if (buf == NULL) return NULL;
	while (i < len) {
		unsigned int cp = p[i++];
		unsigned int minimum = 0;
		int following = 0;
		if (cp < 0x80) {
			// ASCII, including embedded NUL.
		} else if (cp >= 0xC2 && cp <= 0xDF) {
			cp &= 0x1F; following = 1; minimum = 0x80;
		} else if (cp >= 0xE0 && cp <= 0xEF) {
			cp &= 0x0F; following = 2; minimum = 0x800;
		} else if (cp >= 0xF0 && cp <= 0xF4) {
			cp &= 0x07; following = 3; minimum = 0x10000;
		} else {
			goto invalid;
		}
		if (following > len - i) goto invalid;
		while (following-- > 0) {
			unsigned int next = p[i++];
			if ((next & 0xC0) != 0x80) goto invalid;
			cp = (cp << 6) | (next & 0x3F);
		}
		if (cp < minimum || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) goto invalid;
		if (cp < 0x10000) {
			buf[units++] = (jchar)cp;
		} else {
			cp -= 0x10000;
			buf[units++] = (jchar)(0xD800 + (cp >> 10));
			buf[units++] = (jchar)(0xDC00 + (cp & 0x3FF));
		}
	}
	result = (*env)->NewString(env, buf, (jsize)units);
	free(buf);
	return result;
invalid:
	free(buf);
	return NULL;
}

// A service object can exist on a device with no vibration motor, and vibrate
// requires the manifest's VIBRATE permission. Check both before claiming support.
static jobject ui2_android_vibrator(JNIEnv *env, ANativeActivity *act) {
	jclass activity_class = (*env)->GetObjectClass(env, act->clazz);
	jmethodID get_service, check_permission, has_vibrator;
	jstring name, permission;
	jobject vibrator;
	jclass vibrator_class;
	if (activity_class == NULL || (*env)->ExceptionCheck(env)) return NULL;
	check_permission = (*env)->GetMethodID(env, activity_class, "checkCallingOrSelfPermission", "(Ljava/lang/String;)I");
	if (check_permission == NULL || (*env)->ExceptionCheck(env)) return NULL;
	permission = (*env)->NewStringUTF(env, "android.permission.VIBRATE");
	if (permission == NULL || (*env)->ExceptionCheck(env)) return NULL;
	if ((*env)->CallIntMethod(env, act->clazz, check_permission, permission) != 0
		|| (*env)->ExceptionCheck(env)) return NULL;
	get_service = (*env)->GetMethodID(env, activity_class, "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;");
	if (get_service == NULL || (*env)->ExceptionCheck(env)) return NULL;
	name = (*env)->NewStringUTF(env, "vibrator");
	if (name == NULL || (*env)->ExceptionCheck(env)) return NULL;
	vibrator = (*env)->CallObjectMethod(env, act->clazz, get_service, name);
	if (vibrator == NULL || (*env)->ExceptionCheck(env)) return NULL;
	vibrator_class = (*env)->GetObjectClass(env, vibrator);
	if (vibrator_class == NULL || (*env)->ExceptionCheck(env)) return NULL;
	has_vibrator = (*env)->GetMethodID(env, vibrator_class, "hasVibrator", "()Z");
	if (has_vibrator == NULL || (*env)->ExceptionCheck(env)) return NULL;
	if (!(*env)->CallBooleanMethod(env, vibrator, has_vibrator) || (*env)->ExceptionCheck(env)) return NULL;
	return vibrator;
}

static int ui2_android_haptic_supported(void *activity) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0, supported;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	supported = ui2_android_vibrator(env, act) != NULL;
	ui2_android_jni_release(act, env, attached);
	return supported;
}

// Android 8+ uses VibrationEffect; older devices use the duration overload.
static int ui2_android_haptic(void *activity, int duration_ms, int amplitude) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0, fired = 0;
	jobject vibrator;
	jclass vibrator_class;
	jmethodID vibrate;
	if (duration_ms <= 0 || amplitude < 1 || amplitude > 255) return 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	vibrator = ui2_android_vibrator(env, act);
	if (vibrator == NULL) goto done;
	vibrator_class = (*env)->GetObjectClass(env, vibrator);
	if (vibrator_class == NULL || (*env)->ExceptionCheck(env)) goto done;
	if (act->sdkVersion >= 26) {
		jclass effect_class = (*env)->FindClass(env, "android/os/VibrationEffect");
		jmethodID create;
		jobject effect;
		if (effect_class == NULL || (*env)->ExceptionCheck(env)) goto done;
		create = (*env)->GetStaticMethodID(env, effect_class, "createOneShot", "(JI)Landroid/os/VibrationEffect;");
		if (create == NULL || (*env)->ExceptionCheck(env)) goto done;
		vibrate = (*env)->GetMethodID(env, vibrator_class, "vibrate", "(Landroid/os/VibrationEffect;)V");
		if (vibrate == NULL || (*env)->ExceptionCheck(env)) goto done;
		effect = (*env)->CallStaticObjectMethod(env, effect_class, create, (jlong)duration_ms, (jint)amplitude);
		if (effect == NULL || (*env)->ExceptionCheck(env)) goto done;
		(*env)->CallVoidMethod(env, vibrator, vibrate, effect);
	} else {
		vibrate = (*env)->GetMethodID(env, vibrator_class, "vibrate", "(J)V");
		if (vibrate == NULL || (*env)->ExceptionCheck(env)) goto done;
		(*env)->CallVoidMethod(env, vibrator, vibrate, (jlong)duration_ms);
	}
	fired = !(*env)->ExceptionCheck(env);
done:
	ui2_android_jni_release(act, env, attached);
	return fired;
}

// Calling through an Activity preserves its task; the render thread is not a
// reason to add FLAG_ACTIVITY_NEW_TASK. The caller owns the JNI local frame.
static int ui2_android_start_activity(JNIEnv *env, ANativeActivity *act, jobject intent) {
	jclass cls = (*env)->GetObjectClass(env, act->clazz);
	jmethodID start;
	if (cls == NULL || (*env)->ExceptionCheck(env)) return 0;
	start = (*env)->GetMethodID(env, cls, "startActivity", "(Landroid/content/Intent;)V");
	if (start == NULL || (*env)->ExceptionCheck(env)) return 0;
	(*env)->CallVoidMethod(env, act->clazz, start, intent);
	return !(*env)->ExceptionCheck(env);
}

static int ui2_android_open_url(void *activity, const char *url, int url_len) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0, started = 0;
	jclass intent_class, uri_class;
	jmethodID view_init, parse, normalize;
	jstring action, target;
	jobject uri, intent;
	if (url == NULL || url_len <= 0) return 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	intent_class = (*env)->FindClass(env, "android/content/Intent");
	if (intent_class == NULL || (*env)->ExceptionCheck(env)) goto done;
	uri_class = (*env)->FindClass(env, "android/net/Uri");
	if (uri_class == NULL || (*env)->ExceptionCheck(env)) goto done;
	view_init = (*env)->GetMethodID(env, intent_class, "<init>", "(Ljava/lang/String;Landroid/net/Uri;)V");
	if (view_init == NULL || (*env)->ExceptionCheck(env)) goto done;
	parse = (*env)->GetStaticMethodID(env, uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;");
	if (parse == NULL || (*env)->ExceptionCheck(env)) goto done;
	normalize = (*env)->GetMethodID(env, uri_class, "normalizeScheme", "()Landroid/net/Uri;");
	if (normalize == NULL || (*env)->ExceptionCheck(env)) goto done;
	action = (*env)->NewStringUTF(env, "android.intent.action.VIEW");
	if (action == NULL || (*env)->ExceptionCheck(env)) goto done;
	target = ui2_android_jstring_from_utf8(env, url, url_len);
	if (target == NULL || (*env)->ExceptionCheck(env)) goto done;
	uri = (*env)->CallStaticObjectMethod(env, uri_class, parse, target);
	if (uri == NULL || (*env)->ExceptionCheck(env)) goto done;
	uri = (*env)->CallObjectMethod(env, uri, normalize);
	if (uri == NULL || (*env)->ExceptionCheck(env)) goto done;
	intent = (*env)->NewObject(env, intent_class, view_init, action, uri);
	if (intent == NULL || (*env)->ExceptionCheck(env)) goto done;
	started = ui2_android_start_activity(env, act, intent);
done:
	ui2_android_jni_release(act, env, attached);
	return started;
}

static int ui2_android_share_text(void *activity, const char *text, int text_len) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JNIEnv *env = NULL;
	int attached = 0, started = 0;
	jclass cls;
	jmethodID init, set_type, put_extra, create_chooser;
	jfieldID extra_text_field;
	jstring action, mime, body, extra_key, title;
	jobject intent, chooser;
	if (text == NULL || text_len <= 0) return 0;
	if (!ui2_android_jni_env(act, &env, &attached)) return 0;
	cls = (*env)->FindClass(env, "android/content/Intent");
	if (cls == NULL || (*env)->ExceptionCheck(env)) goto done;
	init = (*env)->GetMethodID(env, cls, "<init>", "(Ljava/lang/String;)V");
	if (init == NULL || (*env)->ExceptionCheck(env)) goto done;
	set_type = (*env)->GetMethodID(env, cls, "setType", "(Ljava/lang/String;)Landroid/content/Intent;");
	if (set_type == NULL || (*env)->ExceptionCheck(env)) goto done;
	put_extra = (*env)->GetMethodID(env, cls, "putExtra", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;");
	if (put_extra == NULL || (*env)->ExceptionCheck(env)) goto done;
	create_chooser = (*env)->GetStaticMethodID(env, cls, "createChooser", "(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;");
	if (create_chooser == NULL || (*env)->ExceptionCheck(env)) goto done;
	extra_text_field = (*env)->GetStaticFieldID(env, cls, "EXTRA_TEXT", "Ljava/lang/String;");
	if (extra_text_field == NULL || (*env)->ExceptionCheck(env)) goto done;
	action = (*env)->NewStringUTF(env, "android.intent.action.SEND");
	if (action == NULL || (*env)->ExceptionCheck(env)) goto done;
	mime = (*env)->NewStringUTF(env, "text/plain");
	if (mime == NULL || (*env)->ExceptionCheck(env)) goto done;
	body = ui2_android_jstring_from_utf8(env, text, text_len);
	if (body == NULL || (*env)->ExceptionCheck(env)) goto done;
	extra_key = (*env)->GetStaticObjectField(env, cls, extra_text_field);
	if (extra_key == NULL || (*env)->ExceptionCheck(env)) goto done;
	intent = (*env)->NewObject(env, cls, init, action);
	if (intent == NULL || (*env)->ExceptionCheck(env)) goto done;
	(*env)->CallObjectMethod(env, intent, set_type, mime);
	if ((*env)->ExceptionCheck(env)) goto done;
	(*env)->CallObjectMethod(env, intent, put_extra, extra_key, body);
	if ((*env)->ExceptionCheck(env)) goto done;
	title = (*env)->NewStringUTF(env, "Share");
	if (title == NULL || (*env)->ExceptionCheck(env)) goto done;
	chooser = (*env)->CallStaticObjectMethod(env, cls, create_chooser, intent, title);
	if (chooser == NULL || (*env)->ExceptionCheck(env)) goto done;
	started = ui2_android_start_activity(env, act, chooser);
done:
	ui2_android_jni_release(act, env, attached);
	return started;
}

#endif
