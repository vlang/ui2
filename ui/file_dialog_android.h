#ifndef UI2_FILE_DIALOG_ANDROID_H
#define UI2_FILE_DIALOG_ANDROID_H

#include <jni.h>
#include <android/native_activity.h>

// ui2_android_start_file_picker asks the activity to open the system document
// picker by calling its startFilePicker(boolean). The method is looked up on the
// activity's own class, so the application's package name does not matter. The
// call comes from the render thread, which is not attached to the JVM, so it is
// attached for the call. Returns 1 when the picker was asked for.
static int ui2_android_start_file_picker(void *activity, int multiple) {
	ANativeActivity *act = (ANativeActivity *)activity;
	JavaVM *vm = act->vm;
	JNIEnv *env = NULL;
	int attached = 0;
	if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_6) != JNI_OK) {
		if ((*vm)->AttachCurrentThread(vm, &env, NULL) != JNI_OK) {
			return 0;
		}
		attached = 1;
	}
	int started = 0;
	jclass cls = (*env)->GetObjectClass(env, act->clazz);
	jmethodID method = (*env)->GetMethodID(env, cls, "startFilePicker", "(Z)V");
	if (method != NULL) {
		(*env)->CallVoidMethod(env, act->clazz, method, (jboolean)(multiple != 0));
		started = 1;
	}
	if ((*env)->ExceptionCheck(env)) {
		(*env)->ExceptionClear(env);
		started = 0;
	}
	(*env)->DeleteLocalRef(env, cls);
	if (attached) {
		(*vm)->DetachCurrentThread(vm);
	}
	return started;
}

#endif
