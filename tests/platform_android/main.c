// Host tests use the NDK's real JNI table and a mock NativeActivity/JVM.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../../ui/platform_android.h"

static int calls, fail_at, pending, frames, locals, pops, attaches, detaches;
static int vm_status = JNI_OK, permission_granted = 1, motor_present = 1;
static int attach_fails, utf16_length;
static jchar utf16[256];
static JNIEnv test_env;

// Ordinary JNI calls with an outstanding exception are a CheckJNI error.
static int step(void) {
	assert(!pending);
	if (++calls == fail_at) { pending = 1; return 0; }
	return 1;
}
static jobject object(void) { ++locals; return (jobject)(uintptr_t)(100 + locals); }
static jboolean exception_check(JNIEnv *env) { (void)env; return pending; }
static void exception_clear(JNIEnv *env) { (void)env; pending = 0; }
static jint push_frame(JNIEnv *env, jint capacity) {
	(void)env; assert(capacity >= 24);
	if (!step()) return JNI_ERR;
	assert(!frames); frames = 1; return JNI_OK;
}
static jobject pop_frame(JNIEnv *env, jobject result) {
	(void)env; assert(!pending && frames == 1 && result == NULL);
	frames = 0; locals = 0; ++pops; return NULL;
}
static jclass find_class(JNIEnv *env, const char *name) {
	(void)env; assert(name); return step() ? (jclass)object() : NULL;
}
static jclass get_class(JNIEnv *env, jobject obj) {
	(void)env; assert(obj); return step() ? (jclass)object() : NULL;
}
static jmethodID method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
	(void)env; assert(cls && sig); return step() ? (jmethodID)name : NULL;
}
static jfieldID field(JNIEnv *env, jclass cls, const char *name, const char *sig) {
	(void)env; assert(cls && name && sig); return step() ? (jfieldID)name : NULL;
}
static jstring new_utf(JNIEnv *env, const char *text) {
	(void)env; assert(text); return step() ? (jstring)object() : NULL;
}
static jstring new_string(JNIEnv *env, const jchar *text, jsize length) {
	(void)env; assert(text && length <= 256);
	if (!step()) return NULL;
	utf16_length = length;
	memcpy(utf16, text, (size_t)length * sizeof(jchar));
	return (jstring)object();
}
static jobject new_object(JNIEnv *env, jclass cls, jmethodID id, ...) {
	(void)env; assert(cls && id); return step() ? object() : NULL;
}
static jobject call_object(JNIEnv *env, jobject obj, jmethodID id, ...) {
	(void)env; assert(obj && id); return step() ? object() : NULL;
}
static jobject call_static(JNIEnv *env, jclass cls, jmethodID id, ...) {
	(void)env; assert(cls && id); return step() ? object() : NULL;
}
static jobject get_static(JNIEnv *env, jclass cls, jfieldID id) {
	(void)env; assert(cls && id); return step() ? object() : NULL;
}
static jint call_int(JNIEnv *env, jobject obj, jmethodID id, ...) {
	(void)env; assert(obj && !strcmp((const char *)id, "checkCallingOrSelfPermission"));
	if (!step()) return -1;
	return permission_granted ? 0 : -1;
}
static jboolean call_bool(JNIEnv *env, jobject obj, jmethodID id, ...) {
	(void)env; assert(obj && !strcmp((const char *)id, "hasVibrator"));
	return step() ? motor_present : 0;
}
static void call_void(JNIEnv *env, jobject obj, jmethodID id, ...) {
	(void)env; assert(obj && id); step();
}
static jint get_env(JavaVM *vm, void **env, jint version) {
	(void)vm; assert(version == JNI_VERSION_1_6);
	*env = &test_env; return vm_status;
}
static jint attach(JavaVM *vm, JNIEnv **env, void *args) {
	(void)vm; (void)args; ++attaches;
	if (attach_fails) return JNI_ERR;
	*env = &test_env; return JNI_OK;
}
static jint detach(JavaVM *vm) { (void)vm; ++detaches; return JNI_OK; }

static const struct JNINativeInterface table = {
	.FindClass = find_class, .GetObjectClass = get_class,
	.GetMethodID = method, .GetStaticMethodID = method,
	.GetStaticFieldID = field, .GetStaticObjectField = get_static,
	.NewStringUTF = new_utf, .NewString = new_string, .NewObject = new_object,
	.CallObjectMethod = call_object, .CallStaticObjectMethod = call_static,
	.CallIntMethod = call_int, .CallBooleanMethod = call_bool, .CallVoidMethod = call_void,
	.ExceptionCheck = exception_check, .ExceptionClear = exception_clear,
	.PushLocalFrame = push_frame, .PopLocalFrame = pop_frame,
};
static const struct JNIInvokeInterface vm_table = {
	.GetEnv = get_env, .AttachCurrentThread = attach, .DetachCurrentThread = detach,
};
static JavaVM vm = &vm_table;
static ANativeActivity activity;

static void reset(void) {
	calls = fail_at = pending = frames = locals = pops = attaches = detaches = 0;
	vm_status = JNI_OK; permission_granted = motor_present = 1;
	attach_fails = utf16_length = 0;
	test_env = &table;
	activity.vm = &vm; activity.clazz = (jobject)(uintptr_t)1; activity.sdkVersion = 26;
}
static int open_link(void) { return ui2_android_open_url(&activity, "https://example.com/", 20); }
static int share(void) { return ui2_android_share_text(&activity, "Hello", 5); }
static int haptic(void) { return ui2_android_haptic(&activity, 20, 80); }
static int old_haptic(void) { activity.sdkVersion = 23; return haptic(); }
static int supported(void) { return ui2_android_haptic_supported(&activity); }

static void test_operation(int (*operation)(void)) {
	int count, failure, detached;
	reset(); assert(operation()); count = calls;
	assert(!pending && !frames && !locals && pops == 1 && !detaches);
	// Fail each lookup/allocation/invocation, on both pre-attached and newly
	// attached threads. No later unsafe JNI call or leaked frame is allowed.
	for (detached = 0; detached <= 1; ++detached) {
		for (failure = 1; failure <= count; ++failure) {
			reset(); fail_at = failure;
			vm_status = detached ? JNI_EDETACHED : JNI_OK;
			assert(!operation());
			assert(calls == failure && !pending && !frames && !locals);
			assert(attaches == detached && detaches == detached);
		}
	}
	reset(); vm_status = JNI_EDETACHED; assert(operation());
	assert(attaches == 1 && detaches == 1);
	reset(); vm_status = JNI_EVERSION; assert(!operation()); assert(!attaches && !frames);
	reset(); vm_status = JNI_EDETACHED; attach_fails = 1;
	assert(!operation()); assert(attaches == 1 && !detaches && !frames);
	reset();
	for (int i = 0; i < 1000; ++i) {
		assert(operation()); assert(!frames && !locals && !pending);
	}
}

static void test_unicode(void) {
	const char bytes[] = {'A', 0, (char)0xC3, (char)0xA9, (char)0xF0, (char)0x9F, (char)0x99, (char)0x82};
	const jchar expected[] = {'A', 0, 0xE9, 0xD83D, 0xDE42};
	const unsigned char invalid[][4] = {
		{0x80}, {0xC0, 0x80}, {0xC2}, {0xC2, 'x'}, {0xE0, 0x80, 0x80},
		{0xED, 0xA0, 0x80}, {0xF0, 0x80, 0x80, 0x80}, {0xF4, 0x90, 0x80, 0x80},
		{0xF0, 0x9F}, {0xF5, 0x80, 0x80, 0x80}
	};
	const int lengths[] = {1, 2, 1, 2, 3, 3, 4, 4, 2, 4};
	reset();
	assert(ui2_android_jstring_from_utf8(&test_env, bytes, sizeof(bytes)));
	assert(utf16_length == 5 && !memcmp(utf16, expected, sizeof(expected)));
	for (unsigned i = 0; i < sizeof(lengths)/sizeof(lengths[0]); ++i) {
		reset();
		assert(!ui2_android_jstring_from_utf8(&test_env, (const char *)invalid[i], lengths[i]));
		assert(calls == 0);
	}
	reset(); assert(ui2_android_share_text(&activity, bytes, sizeof(bytes)));
	assert(utf16_length == 5 && !memcmp(utf16, expected, sizeof(expected)));
}

int main(void) {
	test_operation(open_link); test_operation(share);
	test_operation(haptic); test_operation(old_haptic); test_operation(supported);
	test_unicode();
	reset(); motor_present = 0; assert(!supported()); assert(!haptic());
	reset(); permission_granted = 0; assert(!supported()); assert(!haptic());
	reset(); assert(!ui2_android_haptic_supported(NULL));
	activity.vm = NULL; assert(!haptic());
	reset(); assert(!ui2_android_haptic(&activity, -1, 80));
	assert(!ui2_android_haptic(&activity, 10, 256));
	puts("Android JNI: Unicode, failed calls, local frames, threads, and haptic capabilities passed.");
	return 0;
}
