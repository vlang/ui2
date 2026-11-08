// SFSpeechRecognizer for ui/speech_darwin.v: on-device dictation from the
// default microphone.
//
// This is plain C, with no Objective-C syntax and no block literals: V may
// build ui2 with tcc, which has neither, and custom-rendered macOS builds
// compile the generated C as Objective-C with ARC. Every object is a void*
// sent messages through objc_msgSend casts, as vlib/macos does, so ARC never
// owns one; the ownership below is manual retain and release.
//
// The two framework calls that take a block (the speech recognition and
// microphone authorization requests) get a hand-built global block: the
// documented Block ABI layout with _NSConcreteGlobalBlock as its isa, which
// the runtime never copies or frees. Results arrive through a delegate class
// built at runtime, and audio through an AudioQueue input callback, a plain C
// function, so capture needs no block at all.
//
// Nothing asks for access unless every Info.plist the system consults has
// both usage descriptions (see ui2_sp_usage_problem): asking without them
// makes macOS terminate the process. Without them the recognizer reports
// itself unavailable, with the reason.
//
// Threads: ui2_speech_open, _check, _start, _pump, _next, _stop and _cancel run
// on the UI thread. The authorization handlers, the delegate and the input
// callback run on threads the system picks; they only touch the bridge under
// its locks and never call into V, whose garbage collector does not know those
// threads. A bridge lives as long as the process, so a late callback always
// finds it.
#ifndef UI2_SPEECH_DARWIN_H
#define UI2_SPEECH_DARWIN_H

#include <dlfcn.h>
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <objc/message.h>
#include <objc/runtime.h>

#if defined(__OBJC__) && defined(__has_feature)
#if __has_feature(objc_arc)
#define UI2_SP_BRIDGE __bridge
#endif
#endif
#ifndef UI2_SP_BRIDGE
#define UI2_SP_BRIDGE
#endif

// Problems, in the order of SpeechNativeProblem in ui/speech.v.
#define UI2_SP_OK 0
#define UI2_SP_FRAMEWORK_MISSING 2
#define UI2_SP_MISSING_SPEECH_USAGE 3
#define UI2_SP_MISSING_MICROPHONE_USAGE 4
#define UI2_SP_MISSING_USAGE 5
#define UI2_SP_NO_RECOGNIZER 6
#define UI2_SP_RECOGNIZER_UNAVAILABLE 7
#define UI2_SP_NOT_ON_DEVICE 8
#define UI2_SP_SPEECH_DENIED 9
#define UI2_SP_SPEECH_RESTRICTED 10
#define UI2_SP_MICROPHONE_DENIED 11
#define UI2_SP_MICROPHONE_RESTRICTED 12
#define UI2_SP_NO_MICROPHONE 13
#define UI2_SP_BUSY 14
#define UI2_SP_RESPONSIBLE_USAGE 15

// Events, in the order of SpeechNativeEventKind in ui/speech.v.
#define UI2_SP_EVENT_PERMISSION 1
#define UI2_SP_EVENT_READY 2
#define UI2_SP_EVENT_LEVEL 3
#define UI2_SP_EVENT_HYPOTHESIS 4
#define UI2_SP_EVENT_RESULT 5
#define UI2_SP_EVENT_DONE 6
#define UI2_SP_EVENT_ERROR 7

// Where a bridge is in its session.
#define UI2_SP_IDLE 0
#define UI2_SP_WAIT_SPEECH 1 // Asked for speech recognition access.
#define UI2_SP_WAIT_MIC 2    // Asked for microphone access.
#define UI2_SP_RUNNING 3     // Capturing and recognizing.
#define UI2_SP_FINISHING 4   // Capture ended; waiting for the final result.

// SFSpeechRecognizerAuthorizationStatus.
#define UI2_SP_SPEECH_NOT_DETERMINED 0
#define UI2_SP_SPEECH_DENIED_STATUS 1
#define UI2_SP_SPEECH_RESTRICTED_STATUS 2
#define UI2_SP_SPEECH_AUTHORIZED 3
// AVAuthorizationStatus: a different order.
#define UI2_SP_MIC_NOT_DETERMINED 0
#define UI2_SP_MIC_RESTRICTED_STATUS 1
#define UI2_SP_MIC_DENIED_STATUS 2
#define UI2_SP_MIC_AUTHORIZED 3

#define UI2_SP_EVENT_CAPACITY 256
#define UI2_SP_BUFFER_COUNT 3
// One buffer is one level: 80 ms of 16 kHz mono.
#define UI2_SP_SAMPLE_RATE 16000.0
#define UI2_SP_BUFFER_FRAMES 1280

typedef struct ui2_speech_event {
	int kind;
	int is_final;
	int ends_utterance;
	int success;
	double value;
	long code;
	char* text;   // malloc'd UTF-8 or NULL; ui2_speech_event_free releases it.
	char* domain; // Likewise.
} ui2_speech_event;

// The Block ABI (clang's "Block Implementation Specification"): a global block
// is never copied to the heap, and retaining or releasing it does nothing. The
// context after the descriptor is ours; the invoke function reads it.
typedef struct ui2_sp_block_descriptor {
	unsigned long reserved;
	unsigned long size;
	const char* signature;
} ui2_sp_block_descriptor;

typedef struct ui2_sp_block {
	void* isa;
	int flags;
	int reserved;
	void* invoke;
	ui2_sp_block_descriptor* descriptor;
	void* context;
} ui2_sp_block;

#define UI2_SP_BLOCK_IS_GLOBAL (1 << 28)
#define UI2_SP_BLOCK_HAS_SIGNATURE (1 << 30)

// AudioToolbox's AudioQueue, declared here and looked up with dlsym so that
// neither its headers nor a link flag are needed.
typedef struct ui2_sp_stream_format {
	double sample_rate;
	uint32_t format_id;
	uint32_t format_flags;
	uint32_t bytes_per_packet;
	uint32_t frames_per_packet;
	uint32_t bytes_per_frame;
	uint32_t channels_per_frame;
	uint32_t bits_per_channel;
	uint32_t reserved;
} ui2_sp_stream_format;

typedef struct ui2_sp_queue_buffer {
	uint32_t capacity;
	void* data;
	uint32_t byte_size;
	void* user_data;
	uint32_t packet_description_capacity;
	void* packet_descriptions;
	uint32_t packet_description_count;
} ui2_sp_queue_buffer;

typedef void (*ui2_sp_input_fn)(void* user, void* queue, ui2_sp_queue_buffer* buffer,
	const void* start_time, uint32_t packets, const void* descriptions);
typedef int32_t (*ui2_sp_new_input_fn)(const ui2_sp_stream_format* format, ui2_sp_input_fn callback,
	void* user, void* run_loop, void* run_loop_mode, uint32_t flags, void** queue);
typedef int32_t (*ui2_sp_allocate_buffer_fn)(void* queue, uint32_t bytes, ui2_sp_queue_buffer** buffer);
typedef int32_t (*ui2_sp_enqueue_buffer_fn)(void* queue, ui2_sp_queue_buffer* buffer, uint32_t packets,
	const void* descriptions);
typedef int32_t (*ui2_sp_start_fn)(void* queue, const void* start_time);
typedef int32_t (*ui2_sp_stop_fn)(void* queue, unsigned char immediate);

typedef struct ui2_speech {
	pthread_mutex_t lock;       // The events and the session state.
	pthread_mutex_t audio_lock; // Capture: the queue, `capturing` and the request's audio.
	ui2_speech_event events[UI2_SP_EVENT_CAPACITY];
	int head;
	int count;
	long generation; // Bumped by every start and cancel; older callbacks are ignored.
	int phase;
	int speech_asking;   // requestAuthorization: is outstanding.
	int speech_answered; // ... and its handler ran with speech_answer.
	int speech_answer;
	int mic_asking;
	int mic_answered;
	int mic_answer;
	int capturing;
	void* recognizer;  // SFSpeechRecognizer, retained.
	void* queue;       // The NSOperationQueue it reports on, retained.
	void* format;      // AVAudioFormat: 16 kHz mono 16-bit, retained.
	void* request;     // SFSpeechAudioBufferRecognitionRequest of the session, retained.
	void* task;        // SFSpeechRecognitionTask of the session, retained.
	void* audio_queue; // AudioQueueRef while capturing.
	void* audio_media_type;
	ui2_sp_new_input_fn new_input;
	ui2_sp_allocate_buffer_fn allocate_buffer;
	ui2_sp_enqueue_buffer_fn enqueue_buffer;
	ui2_sp_start_fn start_queue;
	ui2_sp_stop_fn stop_queue;
	ui2_sp_stop_fn dispose_queue;
	ui2_sp_block speech_block;
	ui2_sp_block mic_block;
	ui2_sp_block_descriptor speech_descriptor;
	ui2_sp_block_descriptor mic_descriptor;
} ui2_speech;

static inline void* ui2_sp_sel(const char* name) {
	return (void*)sel_registerName(name);
}

static inline void* ui2_sp_class(const char* name) {
	return (UI2_SP_BRIDGE void*)objc_getClass(name);
}

static inline void* ui2_sp_msg(void* obj, const char* sel) {
	if (obj == NULL) return NULL;
	return ((void* (*)(void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel));
}

static inline void* ui2_sp_msg1(void* obj, const char* sel, void* a) {
	if (obj == NULL) return NULL;
	return ((void* (*)(void*, void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel), a);
}

static inline void* ui2_sp_msg2(void* obj, const char* sel, void* a, void* b) {
	if (obj == NULL) return NULL;
	return ((void* (*)(void*, void*, void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel), a, b);
}

static inline void ui2_sp_send(void* obj, const char* sel) {
	if (obj == NULL) return;
	((void (*)(void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel));
}

static inline void ui2_sp_send1(void* obj, const char* sel, void* a) {
	if (obj == NULL) return;
	((void (*)(void*, void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel), a);
}

static inline void ui2_sp_send_bool(void* obj, const char* sel, int value) {
	if (obj == NULL) return;
	((void (*)(void*, void*, signed char))objc_msgSend)(obj, ui2_sp_sel(sel), (signed char)(value != 0));
}

static inline void ui2_sp_send_long(void* obj, const char* sel, long value) {
	if (obj == NULL) return;
	((void (*)(void*, void*, long))objc_msgSend)(obj, ui2_sp_sel(sel), value);
}

static inline int ui2_sp_bool(void* obj, const char* sel) {
	if (obj == NULL) return 0;
	return ((signed char (*)(void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel)) != 0;
}

static inline long ui2_sp_long(void* obj, const char* sel) {
	if (obj == NULL) return 0;
	return ((long (*)(void*, void*))objc_msgSend)(obj, ui2_sp_sel(sel));
}

static inline int ui2_sp_responds(void* obj, const char* sel) {
	if (obj == NULL) return 0;
	return class_respondsToSelector(object_getClass((UI2_SP_BRIDGE id)obj), sel_registerName(sel)) ? 1 : 0;
}

static inline void* ui2_sp_new(const char* class_name) {
	return ui2_sp_msg(ui2_sp_msg(ui2_sp_class(class_name), "alloc"), "init");
}

static inline void ui2_sp_release(void* obj) {
	ui2_sp_send(obj, "release");
}

static inline void* ui2_sp_retain(void* obj) {
	return ui2_sp_msg(obj, "retain");
}

static inline void* ui2_sp_string(const char* text) {
	return ((void* (*)(void*, void*, const char*))objc_msgSend)(ui2_sp_class("NSString"),
		ui2_sp_sel("stringWithUTF8String:"), text);
}

// ui2_sp_dup copies an NSString into malloc'd UTF-8, or returns NULL.
static inline char* ui2_sp_dup(void* string) {
	if (string == NULL) return NULL;
	const char* utf8 = ((const char* (*)(void*, void*))objc_msgSend)(string, ui2_sp_sel("UTF8String"));
	if (utf8 == NULL) return NULL;
	size_t length = strlen(utf8);
	char* copy = (char*)malloc(length + 1);
	if (copy != NULL) memcpy(copy, utf8, length + 1);
	return copy;
}

// Autorelease pools for callers outside a run loop, such as the audio thread.
static inline void* ui2_sp_pool_push(void) {
	return ui2_sp_new("NSAutoreleasePool");
}

static inline void ui2_sp_pool_pop(void* pool) {
	ui2_sp_send(pool, "drain");
}

static inline void ui2_speech_event_free(ui2_speech_event* event) {
	free(event->text);
	free(event->domain);
	event->text = NULL;
	event->domain = NULL;
}

// ui2_sp_push queues an event, taking its strings. Call with `lock` held. A
// full queue drops its oldest event: the UI thread is not draining it.
static void ui2_sp_push(ui2_speech* b, ui2_speech_event event) {
	if (b->count == UI2_SP_EVENT_CAPACITY) {
		ui2_speech_event_free(&b->events[b->head]);
		b->head = (b->head + 1) % UI2_SP_EVENT_CAPACITY;
		b->count--;
	}
	b->events[(b->head + b->count) % UI2_SP_EVENT_CAPACITY] = event;
	b->count++;
}

static void ui2_sp_push_kind(ui2_speech* b, int kind, long code) {
	ui2_speech_event event;
	memset(&event, 0, sizeof(event));
	event.kind = kind;
	event.code = code;
	ui2_sp_push(b, event);
}

static void ui2_sp_clear_events(ui2_speech* b) {
	while (b->count > 0) {
		ui2_speech_event_free(&b->events[b->head]);
		b->head = (b->head + 1) % UI2_SP_EVENT_CAPACITY;
		b->count--;
	}
	b->head = 0;
}

// ui2_speech_next moves the oldest event into `out`; it reports whether there
// was one. The caller frees its strings with ui2_speech_event_free.
static int ui2_speech_next(ui2_speech* b, ui2_speech_event* out) {
	int found = 0;
	pthread_mutex_lock(&b->lock);
	if (b->count > 0) {
		*out = b->events[b->head];
		memset(&b->events[b->head], 0, sizeof(ui2_speech_event));
		b->head = (b->head + 1) % UI2_SP_EVENT_CAPACITY;
		b->count--;
		found = 1;
	}
	pthread_mutex_unlock(&b->lock);
	return found;
}

// --- Blocks -----------------------------------------------------------------

static int ui2_sp_block_init(ui2_sp_block* block, ui2_sp_block_descriptor* descriptor,
	const char* signature, void* invoke, void* context) {
	void* isa = dlsym(RTLD_DEFAULT, "_NSConcreteGlobalBlock");
	if (isa == NULL) return 0;
	descriptor->reserved = 0;
	descriptor->size = sizeof(ui2_sp_block);
	descriptor->signature = signature;
	block->isa = isa;
	block->flags = UI2_SP_BLOCK_IS_GLOBAL | UI2_SP_BLOCK_HAS_SIGNATURE;
	block->reserved = 0;
	block->invoke = invoke;
	block->descriptor = descriptor;
	block->context = context;
	return 1;
}

// ^(SFSpeechRecognizerAuthorizationStatus status), on any queue.
static void ui2_sp_speech_answered(ui2_sp_block* block, long status) {
	ui2_speech* b = (ui2_speech*)block->context;
	pthread_mutex_lock(&b->lock);
	b->speech_asking = 0;
	b->speech_answered = 1;
	b->speech_answer = (int)status;
	pthread_mutex_unlock(&b->lock);
}

// ^(BOOL granted), on any queue.
static void ui2_sp_mic_answered(ui2_sp_block* block, signed char granted) {
	ui2_speech* b = (ui2_speech*)block->context;
	pthread_mutex_lock(&b->lock);
	b->mic_asking = 0;
	b->mic_answered = 1;
	b->mic_answer = granted != 0;
	pthread_mutex_unlock(&b->lock);
}

// --- Authorization ------------------------------------------------------------

static long ui2_sp_speech_status(void) {
	return ui2_sp_long(ui2_sp_class("SFSpeechRecognizer"), "authorizationStatus");
}

static long ui2_sp_mic_status(ui2_speech* b) {
	void* device = ui2_sp_class("AVCaptureDevice");
	if (device == NULL || b->audio_media_type == NULL) return UI2_SP_MIC_AUTHORIZED;
	return ((long (*)(void*, void*, void*))objc_msgSend)(device,
		ui2_sp_sel("authorizationStatusForMediaType:"), b->audio_media_type);
}

// --- Usage descriptions ---------------------------------------------------------
//
// Asking for speech recognition or microphone access without a usage
// description in the Info.plist makes the system terminate the process, so
// nothing asks unless every Info.plist the system may consult has both keys:
//  - the app's own: its bundle's Info.plist or, for a bare executable, the one
//    embedded with `-sectcreate __TEXT __info_plist`. Foundation also reads an
//    Info.plist lying next to a bare executable, which the privacy checks need
//    not, so that one does not count;
//  - the responsible app's, when the process was started by another app (a
//    terminal, an IDE): macOS asks on that app's behalf and checks its keys.

// ui2_sp_string_key reports whether a dictionary holds a non-empty string.
static int ui2_sp_string_key(void* dictionary, const char* key) {
	if (dictionary == NULL || !ui2_sp_responds(dictionary, "objectForKey:")) return 0;
	void* value = ui2_sp_msg1(dictionary, "objectForKey:", ui2_sp_string(key));
	if (value == NULL || !ui2_sp_responds(value, "length")) return 0;
	return ui2_sp_long(value, "length") > 0;
}

// ui2_sp_embedded_info parses the Info.plist embedded in the main executable,
// or returns NULL. Image 0 is the main executable.
static void* ui2_sp_embedded_info(void) {
	typedef const void* (*header_fn)(uint32_t);
	typedef uint8_t* (*section_fn)(const void*, const char*, const char*, unsigned long*);
	header_fn header = (header_fn)dlsym(RTLD_DEFAULT, "_dyld_get_image_header");
	section_fn section = (section_fn)dlsym(RTLD_DEFAULT, "getsectiondata");
	if (header == NULL || section == NULL || header(0) == NULL) return NULL;
	unsigned long size = 0;
	uint8_t* bytes = section(header(0), "__TEXT", "__info_plist", &size);
	if (bytes == NULL || size == 0) return NULL;
	void* data = ((void* (*)(void*, void*, const void*, unsigned long))objc_msgSend)(ui2_sp_class("NSData"),
		ui2_sp_sel("dataWithBytes:length:"), bytes, size);
	if (data == NULL) return NULL;
	return ((void* (*)(void*, void*, void*, unsigned long, void*, void*))objc_msgSend)(
		ui2_sp_class("NSPropertyListSerialization"), ui2_sp_sel("propertyListWithData:options:format:error:"),
		data, 0, NULL, NULL);
}

// ui2_sp_own_info is the app's own Info.plist as the privacy checks read it.
static void* ui2_sp_own_info(void) {
	void* bundle = ui2_sp_msg(ui2_sp_class("NSBundle"), "mainBundle");
	void* bundle_path = ui2_sp_msg(bundle, "bundlePath");
	void* executable_dir = ui2_sp_msg(ui2_sp_msg(bundle, "executablePath"), "stringByDeletingLastPathComponent");
	if (bundle_path != NULL && executable_dir != NULL
		&& !((signed char (*)(void*, void*, void*))objc_msgSend)(bundle_path, ui2_sp_sel("isEqualToString:"),
			executable_dir)) {
		// A real bundle: the executable is in Contents/MacOS, not at its root.
		return ui2_sp_msg(bundle, "infoDictionary");
	}
	return ui2_sp_embedded_info();
}

// ui2_sp_responsible_pid is the process macOS holds responsible for this one's
// privacy access, or -1 when that cannot be told.
static int ui2_sp_responsible_pid(void) {
	typedef int (*responsible_fn)(int);
	responsible_fn responsible = (responsible_fn)dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid");
	if (responsible == NULL) return -1;
	int pid = responsible((int)getpid());
	return pid > 0 ? pid : -1;
}

// ui2_sp_app_info is the Info.plist of the app bundle whose executable process
// pid runs, or NULL.
static void* ui2_sp_app_info(int pid) {
	typedef int (*path_fn)(int, void*, uint32_t);
	path_fn pid_path = (path_fn)dlsym(RTLD_DEFAULT, "proc_pidpath");
	if (pid_path == NULL) return NULL;
	char path[4096];
	memset(path, 0, sizeof(path));
	if (pid_path(pid, path, (uint32_t)sizeof(path) - 1) <= 0) return NULL;
	// The innermost .app around the executable.
	char* app = NULL;
	for (char* found = strstr(path, ".app/"); found != NULL; found = strstr(found + 1, ".app/")) app = found;
	if (app == NULL) return NULL;
	app[4] = 0;
	void* bundle = ui2_sp_msg1(ui2_sp_class("NSBundle"), "bundleWithPath:", ui2_sp_string(path));
	return ui2_sp_msg(bundle, "infoDictionary");
}

// ui2_sp_usage_problem reports which usage descriptions are missing, or
// UI2_SP_OK when asking is safe.
static int ui2_sp_usage_problem(void) {
	void* own = ui2_sp_own_info();
	int has_speech = ui2_sp_string_key(own, "NSSpeechRecognitionUsageDescription");
	int has_mic = ui2_sp_string_key(own, "NSMicrophoneUsageDescription");
	if (!has_speech || !has_mic) {
		return !has_speech && !has_mic ? UI2_SP_MISSING_USAGE
			: (!has_speech ? UI2_SP_MISSING_SPEECH_USAGE : UI2_SP_MISSING_MICROPHONE_USAGE);
	}
	int responsible = ui2_sp_responsible_pid();
	if (responsible == (int)getpid()) return UI2_SP_OK;
	void* other = responsible > 0 ? ui2_sp_app_info(responsible) : NULL;
	if (ui2_sp_string_key(other, "NSSpeechRecognitionUsageDescription")
		&& ui2_sp_string_key(other, "NSMicrophoneUsageDescription")) {
		return UI2_SP_OK;
	}
	return UI2_SP_RESPONSIBLE_USAGE;
}

// --- Delegate ----------------------------------------------------------------

// A delegate is made per session and remembers the bridge and the session's
// generation, so a task that was cancelled or replaced cannot report into the
// next session. Whether a task holds its delegate strongly is not documented,
// so delegates are never released: one small object per dictation.
static ui2_speech* ui2_sp_delegate_bridge(void* self, long* generation) {
	Class cls = object_getClass((UI2_SP_BRIDGE id)self);
	Ivar bridge_ivar = class_getInstanceVariable(cls, "ui2_bridge");
	Ivar generation_ivar = class_getInstanceVariable(cls, "ui2_generation");
	if (bridge_ivar == NULL || generation_ivar == NULL) return NULL;
	*generation = *(long*)((char*)self + ivar_getOffset(generation_ivar));
	return *(ui2_speech**)((char*)self + ivar_getOffset(bridge_ivar));
}

// ui2_sp_report queues an event from a delegate callback if its session is
// still the bridge's, and frees its strings otherwise.
static void ui2_sp_report(void* self, ui2_speech_event event) {
	long generation = 0;
	ui2_speech* b = ui2_sp_delegate_bridge(self, &generation);
	if (b == NULL) {
		ui2_speech_event_free(&event);
		return;
	}
	pthread_mutex_lock(&b->lock);
	if (generation == b->generation && (b->phase == UI2_SP_RUNNING || b->phase == UI2_SP_FINISHING)) {
		ui2_sp_push(b, event);
	} else {
		ui2_speech_event_free(&event);
	}
	pthread_mutex_unlock(&b->lock);
}

// -speechRecognitionTask:didHypothesizeTranscription:
static void ui2_sp_did_hypothesize(void* self, void* cmd, void* task, void* transcription) {
	ui2_speech_event event;
	memset(&event, 0, sizeof(event));
	event.kind = UI2_SP_EVENT_HYPOTHESIS;
	event.text = ui2_sp_dup(ui2_sp_msg(transcription, "formattedString"));
	ui2_sp_report(self, event);
}

// -speechRecognitionTask:didFinishRecognition:, with a result that ends an
// utterance or, when final, the session.
static void ui2_sp_did_finish_recognition(void* self, void* cmd, void* task, void* result) {
	ui2_speech_event event;
	memset(&event, 0, sizeof(event));
	event.kind = UI2_SP_EVENT_RESULT;
	event.text = ui2_sp_dup(ui2_sp_msg(ui2_sp_msg(result, "bestTranscription"), "formattedString"));
	event.is_final = ui2_sp_bool(result, "isFinal");
	event.ends_utterance = !event.is_final || (ui2_sp_responds(result, "speechRecognitionMetadata")
		&& ui2_sp_msg(result, "speechRecognitionMetadata") != NULL);
	ui2_sp_report(self, event);
}

// -speechRecognitionTask:didFinishSuccessfully:, the task's last word.
static void ui2_sp_did_finish(void* self, void* cmd, void* task, signed char successfully) {
	ui2_speech_event event;
	memset(&event, 0, sizeof(event));
	event.kind = UI2_SP_EVENT_DONE;
	event.success = successfully != 0;
	if (!event.success) {
		void* error = ui2_sp_msg(task, "error");
		if (error != NULL) {
			event.domain = ui2_sp_dup(ui2_sp_msg(error, "domain"));
			event.code = ui2_sp_long(error, "code");
			event.text = ui2_sp_dup(ui2_sp_msg(error, "localizedDescription"));
		}
	}
	ui2_sp_report(self, event);
}

static void* ui2_sp_delegate_class(void) {
	void* existing = ui2_sp_class("UI2SpeechTaskDelegate");
	if (existing != NULL) return existing;
	Class cls = objc_allocateClassPair(objc_getClass("NSObject"), "UI2SpeechTaskDelegate", 0);
	if (cls == NULL) return NULL;
	class_addIvar(cls, "ui2_bridge", sizeof(void*), sizeof(void*) == 8 ? 3 : 2, "^v");
	class_addIvar(cls, "ui2_generation", sizeof(long), sizeof(long) == 8 ? 3 : 2, "q");
	class_addMethod(cls, sel_registerName("speechRecognitionTask:didHypothesizeTranscription:"),
		(IMP)ui2_sp_did_hypothesize, "v@:@@");
	class_addMethod(cls, sel_registerName("speechRecognitionTask:didFinishRecognition:"),
		(IMP)ui2_sp_did_finish_recognition, "v@:@@");
#if defined(__arm64__) || defined(__aarch64__)
	class_addMethod(cls, sel_registerName("speechRecognitionTask:didFinishSuccessfully:"),
		(IMP)ui2_sp_did_finish, "v@:@B");
#else
	class_addMethod(cls, sel_registerName("speechRecognitionTask:didFinishSuccessfully:"),
		(IMP)ui2_sp_did_finish, "v@:@c");
#endif
	objc_registerClassPair(cls);
	return (UI2_SP_BRIDGE void*)cls;
}

static void* ui2_sp_new_delegate(ui2_speech* b, long generation) {
	void* cls = ui2_sp_delegate_class();
	void* delegate = ui2_sp_msg(ui2_sp_msg(cls, "alloc"), "init");
	if (delegate == NULL) return NULL;
	Ivar bridge_ivar = class_getInstanceVariable((UI2_SP_BRIDGE Class)cls, "ui2_bridge");
	Ivar generation_ivar = class_getInstanceVariable((UI2_SP_BRIDGE Class)cls, "ui2_generation");
	if (bridge_ivar == NULL || generation_ivar == NULL) {
		ui2_sp_release(delegate);
		return NULL;
	}
	*(ui2_speech**)((char*)delegate + ivar_getOffset(bridge_ivar)) = b;
	*(long*)((char*)delegate + ivar_getOffset(generation_ivar)) = generation;
	return delegate;
}

// --- Capture -------------------------------------------------------------------

// The AudioQueue input callback, on the queue's own thread: measure the
// buffer, hand it to the recognition request and give it back to the queue.
static void ui2_sp_input(void* user, void* queue, ui2_sp_queue_buffer* buffer, const void* start_time,
	uint32_t packets, const void* descriptions) {
	ui2_speech* b = (ui2_speech*)user;
	void* pool = ui2_sp_pool_push();
	double rms = -1;
	pthread_mutex_lock(&b->audio_lock);
	if (b->capturing && queue == b->audio_queue) {
		uint32_t frames = buffer->byte_size / 2;
		const int16_t* samples = (const int16_t*)buffer->data;
		if (frames > 0 && samples != NULL) {
			double sum = 0;
			for (uint32_t i = 0; i < frames; i++) {
				double value = samples[i] / 32767.0;
				sum += value * value;
			}
			rms = sqrt(sum / frames);
			void* pcm = ((void* (*)(void*, void*, void*, uint32_t))objc_msgSend)(
				ui2_sp_msg(ui2_sp_class("AVAudioPCMBuffer"), "alloc"),
				ui2_sp_sel("initWithPCMFormat:frameCapacity:"), b->format, frames);
			if (pcm != NULL) {
				int16_t* const* channels = ((int16_t* const* (*)(void*, void*))objc_msgSend)(pcm,
					ui2_sp_sel("int16ChannelData"));
				if (channels != NULL && channels[0] != NULL) {
					memcpy(channels[0], samples, frames * 2);
					((void (*)(void*, void*, uint32_t))objc_msgSend)(pcm, ui2_sp_sel("setFrameLength:"),
						frames);
					ui2_sp_send1(b->request, "appendAudioPCMBuffer:", pcm);
				}
				ui2_sp_release(pcm);
			}
		}
		b->enqueue_buffer(queue, buffer, 0, NULL);
	}
	pthread_mutex_unlock(&b->audio_lock);
	if (rms >= 0) {
		pthread_mutex_lock(&b->lock);
		ui2_speech_event event;
		memset(&event, 0, sizeof(event));
		event.kind = UI2_SP_EVENT_LEVEL;
		event.value = rms;
		ui2_sp_push(b, event);
		pthread_mutex_unlock(&b->lock);
	}
	ui2_sp_pool_pop(pool);
}

// ui2_sp_stop_capture stops and disposes of the audio queue. The queue is
// stopped without holding the audio lock, which its callback takes; once
// AudioQueueDispose returns, the callback does not run again.
static void ui2_sp_stop_capture(ui2_speech* b) {
	pthread_mutex_lock(&b->audio_lock);
	void* queue = b->audio_queue;
	b->capturing = 0;
	pthread_mutex_unlock(&b->audio_lock);
	if (queue == NULL) return;
	b->stop_queue(queue, 1);
	b->dispose_queue(queue, 1);
	pthread_mutex_lock(&b->audio_lock);
	if (b->audio_queue == queue) b->audio_queue = NULL;
	pthread_mutex_unlock(&b->audio_lock);
}

static int ui2_sp_start_capture(ui2_speech* b) {
	ui2_sp_stream_format format;
	memset(&format, 0, sizeof(format));
	format.sample_rate = UI2_SP_SAMPLE_RATE;
	format.format_id = 0x6C70636D; // 'lpcm'
	format.format_flags = (1u << 2) | (1u << 3); // Signed integer, packed.
	format.bytes_per_packet = 2;
	format.frames_per_packet = 1;
	format.bytes_per_frame = 2;
	format.channels_per_frame = 1;
	format.bits_per_channel = 16;
	void* queue = NULL;
	if (b->new_input(&format, ui2_sp_input, b, NULL, NULL, 0, &queue) != 0 || queue == NULL) {
		return 0;
	}
	for (int i = 0; i < UI2_SP_BUFFER_COUNT; i++) {
		ui2_sp_queue_buffer* buffer = NULL;
		if (b->allocate_buffer(queue, UI2_SP_BUFFER_FRAMES * 2, &buffer) != 0 || buffer == NULL
			|| b->enqueue_buffer(queue, buffer, 0, NULL) != 0) {
			b->dispose_queue(queue, 1);
			return 0;
		}
	}
	pthread_mutex_lock(&b->audio_lock);
	b->audio_queue = queue;
	b->capturing = 1;
	pthread_mutex_unlock(&b->audio_lock);
	if (b->start_queue(queue, NULL) != 0) {
		ui2_sp_stop_capture(b);
		return 0;
	}
	return 1;
}

// --- Sessions ------------------------------------------------------------------

static void ui2_sp_release_session(ui2_speech* b) {
	void* task = b->task;
	void* request = b->request;
	b->task = NULL;
	b->request = NULL;
	if (task != NULL) {
		ui2_sp_send(task, "cancel");
		ui2_sp_release(task);
	}
	ui2_sp_release(request);
}

// ui2_sp_begin starts recognizing once both accesses are granted.
static int ui2_sp_begin(ui2_speech* b) {
	void* pool = ui2_sp_pool_push();
	long generation;
	pthread_mutex_lock(&b->lock);
	generation = b->generation;
	pthread_mutex_unlock(&b->lock);
	int problem = UI2_SP_OK;
	void* request = ui2_sp_new("SFSpeechAudioBufferRecognitionRequest");
	void* delegate = ui2_sp_new_delegate(b, generation);
	if (request == NULL || delegate == NULL) {
		ui2_sp_release(request);
		ui2_sp_pool_pop(pool);
		return UI2_SP_FRAMEWORK_MISSING;
	}
	ui2_sp_send_bool(request, "setShouldReportPartialResults:", 1);
	// Never send audio to Apple's servers.
	ui2_sp_send_bool(request, "setRequiresOnDeviceRecognition:", 1);
	if (ui2_sp_responds(request, "setAddsPunctuation:")) {
		ui2_sp_send_bool(request, "setAddsPunctuation:", 1);
	}
	pthread_mutex_lock(&b->audio_lock);
	b->request = request;
	pthread_mutex_unlock(&b->audio_lock);
	pthread_mutex_lock(&b->lock);
	b->phase = UI2_SP_RUNNING;
	pthread_mutex_unlock(&b->lock);
	b->task = ui2_sp_retain(ui2_sp_msg2(b->recognizer, "recognitionTaskWithRequest:delegate:", request,
		delegate));
	if (b->task == NULL) {
		problem = UI2_SP_RECOGNIZER_UNAVAILABLE;
	} else if (!ui2_sp_start_capture(b)) {
		problem = UI2_SP_NO_MICROPHONE;
	}
	if (problem != UI2_SP_OK) {
		// Capture never started, or ui2_sp_start_capture took it down again.
		ui2_sp_release_session(b);
		pthread_mutex_lock(&b->lock);
		b->phase = UI2_SP_IDLE;
		pthread_mutex_unlock(&b->lock);
	} else {
		pthread_mutex_lock(&b->lock);
		ui2_sp_push_kind(b, UI2_SP_EVENT_READY, 0);
		pthread_mutex_unlock(&b->lock);
	}
	ui2_sp_pool_pop(pool);
	return problem;
}

// ui2_sp_ask_microphone begins when the microphone is allowed, and otherwise
// asks for it or reports why not.
static int ui2_sp_ask_microphone(ui2_speech* b) {
	long status = ui2_sp_mic_status(b);
	if (status == UI2_SP_MIC_AUTHORIZED) return ui2_sp_begin(b);
	if (status == UI2_SP_MIC_DENIED_STATUS) return UI2_SP_MICROPHONE_DENIED;
	if (status == UI2_SP_MIC_RESTRICTED_STATUS) return UI2_SP_MICROPHONE_RESTRICTED;
	pthread_mutex_lock(&b->lock);
	int ask = !b->mic_asking;
	if (ask) {
		b->mic_asking = 1;
		b->mic_answered = 0;
	}
	if (b->phase != UI2_SP_WAIT_SPEECH) ui2_sp_push_kind(b, UI2_SP_EVENT_PERMISSION, 0);
	b->phase = UI2_SP_WAIT_MIC;
	pthread_mutex_unlock(&b->lock);
	if (ask) {
		((void (*)(void*, void*, void*, void*))objc_msgSend)(ui2_sp_class("AVCaptureDevice"),
			ui2_sp_sel("requestAccessForMediaType:completionHandler:"), b->audio_media_type, &b->mic_block);
	}
	return UI2_SP_OK;
}

// ui2_speech_open makes a bridge for locale (a BCP 47 tag, or empty for the
// system language), or reports why there cannot be one.
static ui2_speech* ui2_speech_open(const char* locale, int* problem) {
	*problem = UI2_SP_OK;
	void* pool = ui2_sp_pool_push();
	int usage = ui2_sp_usage_problem();
	if (usage != UI2_SP_OK) {
		*problem = usage;
		ui2_sp_pool_pop(pool);
		return NULL;
	}
	void* speech = dlopen("/System/Library/Frameworks/Speech.framework/Speech", RTLD_LAZY | RTLD_LOCAL);
	void* avfoundation = dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
		RTLD_LAZY | RTLD_LOCAL);
	void* toolbox = dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox",
		RTLD_LAZY | RTLD_LOCAL);
	if (speech == NULL || avfoundation == NULL || toolbox == NULL
		|| ui2_sp_class("SFSpeechRecognizer") == NULL || ui2_sp_class("AVAudioPCMBuffer") == NULL) {
		*problem = UI2_SP_FRAMEWORK_MISSING;
		ui2_sp_pool_pop(pool);
		return NULL;
	}
	ui2_speech* b = (ui2_speech*)calloc(1, sizeof(ui2_speech));
	if (b == NULL) {
		*problem = UI2_SP_FRAMEWORK_MISSING;
		ui2_sp_pool_pop(pool);
		return NULL;
	}
	pthread_mutex_init(&b->lock, NULL);
	pthread_mutex_init(&b->audio_lock, NULL);
	b->new_input = (ui2_sp_new_input_fn)dlsym(toolbox, "AudioQueueNewInput");
	b->allocate_buffer = (ui2_sp_allocate_buffer_fn)dlsym(toolbox, "AudioQueueAllocateBuffer");
	b->enqueue_buffer = (ui2_sp_enqueue_buffer_fn)dlsym(toolbox, "AudioQueueEnqueueBuffer");
	b->start_queue = (ui2_sp_start_fn)dlsym(toolbox, "AudioQueueStart");
	b->stop_queue = (ui2_sp_stop_fn)dlsym(toolbox, "AudioQueueStop");
	b->dispose_queue = (ui2_sp_stop_fn)dlsym(toolbox, "AudioQueueDispose");
	void** media_type = (void**)dlsym(avfoundation, "AVMediaTypeAudio");
	b->audio_media_type = media_type != NULL && *media_type != NULL ? *media_type
		: ui2_sp_retain(ui2_sp_string("soun"));
#if defined(__arm64__) || defined(__aarch64__)
	const char* mic_signature = "v12@?0B8";
#else
	const char* mic_signature = "v12@?0c8";
#endif
	int blocks = ui2_sp_block_init(&b->speech_block, &b->speech_descriptor, "v16@?0q8",
		(void*)ui2_sp_speech_answered, b)
		&& ui2_sp_block_init(&b->mic_block, &b->mic_descriptor, mic_signature, (void*)ui2_sp_mic_answered, b);
	if (b->new_input == NULL || b->allocate_buffer == NULL || b->enqueue_buffer == NULL
		|| b->start_queue == NULL || b->stop_queue == NULL || b->dispose_queue == NULL || !blocks
		|| ui2_sp_delegate_class() == NULL) {
		*problem = UI2_SP_FRAMEWORK_MISSING;
		ui2_sp_pool_pop(pool);
		return NULL; // The half-made bridge is left behind: this only happens once.
	}
	void* recognizer = ui2_sp_msg(ui2_sp_class("SFSpeechRecognizer"), "alloc");
	if (locale != NULL && locale[0] != 0) {
		void* identifier = ui2_sp_msg1(ui2_sp_msg(ui2_sp_class("NSLocale"), "alloc"),
			"initWithLocaleIdentifier:", ui2_sp_string(locale));
		recognizer = ui2_sp_msg1(recognizer, "initWithLocale:", identifier);
		ui2_sp_release(identifier);
	} else {
		recognizer = ui2_sp_msg(recognizer, "init");
	}
	b->recognizer = recognizer;
	if (recognizer != NULL) {
		// Results arrive on a queue of our own, so they do not depend on the
		// main queue being serviced.
		b->queue = ui2_sp_new("NSOperationQueue");
		ui2_sp_send_long(b->queue, "setMaxConcurrentOperationCount:", 1);
		ui2_sp_send1(recognizer, "setQueue:", b->queue);
	}
	b->format = ((void* (*)(void*, void*, unsigned long, double, uint32_t, signed char))objc_msgSend)(
		ui2_sp_msg(ui2_sp_class("AVAudioFormat"), "alloc"),
		ui2_sp_sel("initWithCommonFormat:sampleRate:channels:interleaved:"), 3 /* Int16 */,
		UI2_SP_SAMPLE_RATE, 1, 0);
	if (b->format == NULL) *problem = UI2_SP_FRAMEWORK_MISSING;
	ui2_sp_pool_pop(pool);
	return b;
}

// ui2_speech_check reports what keeps a session from starting now, without
// asking anything.
static int ui2_speech_check(ui2_speech* b) {
	if (b->recognizer == NULL) return UI2_SP_NO_RECOGNIZER;
	if (b->format == NULL) return UI2_SP_FRAMEWORK_MISSING;
	if (!ui2_sp_bool(b->recognizer, "isAvailable")) return UI2_SP_RECOGNIZER_UNAVAILABLE;
	if (ui2_sp_responds(b->recognizer, "supportsOnDeviceRecognition")
		&& !ui2_sp_bool(b->recognizer, "supportsOnDeviceRecognition")) {
		return UI2_SP_NOT_ON_DEVICE;
	}
	long speech = ui2_sp_speech_status();
	if (speech == UI2_SP_SPEECH_DENIED_STATUS) return UI2_SP_SPEECH_DENIED;
	if (speech == UI2_SP_SPEECH_RESTRICTED_STATUS) return UI2_SP_SPEECH_RESTRICTED;
	long mic = ui2_sp_mic_status(b);
	if (mic == UI2_SP_MIC_DENIED_STATUS) return UI2_SP_MICROPHONE_DENIED;
	if (mic == UI2_SP_MIC_RESTRICTED_STATUS) return UI2_SP_MICROPHONE_RESTRICTED;
	return UI2_SP_OK;
}

// ui2_speech_start starts a session: at once when access is granted,
// otherwise after asking for it (ui2_speech_pump follows the answers).
static int ui2_speech_start(ui2_speech* b) {
	int problem = ui2_speech_check(b);
	if (problem != UI2_SP_OK) return problem;
	pthread_mutex_lock(&b->lock);
	if (b->phase != UI2_SP_IDLE) {
		pthread_mutex_unlock(&b->lock);
		return UI2_SP_BUSY;
	}
	b->generation++;
	ui2_sp_clear_events(b);
	pthread_mutex_unlock(&b->lock);
	long status = ui2_sp_speech_status();
	if (status == UI2_SP_SPEECH_AUTHORIZED) return ui2_sp_ask_microphone(b);
	pthread_mutex_lock(&b->lock);
	int ask = !b->speech_asking;
	if (ask) {
		b->speech_asking = 1;
		b->speech_answered = 0;
	}
	b->phase = UI2_SP_WAIT_SPEECH;
	ui2_sp_push_kind(b, UI2_SP_EVENT_PERMISSION, 0);
	pthread_mutex_unlock(&b->lock);
	if (ask) {
		((void (*)(void*, void*, void*))objc_msgSend)(ui2_sp_class("SFSpeechRecognizer"),
			ui2_sp_sel("requestAuthorization:"), &b->speech_block);
	}
	return UI2_SP_OK;
}

static void ui2_sp_fail(ui2_speech* b, int problem) {
	pthread_mutex_lock(&b->lock);
	b->phase = UI2_SP_IDLE;
	ui2_sp_push_kind(b, UI2_SP_EVENT_ERROR, problem);
	pthread_mutex_unlock(&b->lock);
}

// ui2_speech_pump follows the answers to the access requests. The statuses
// are read as well as the handlers' answers, so a session goes on even if a
// handler were never called.
static void ui2_speech_pump(ui2_speech* b) {
	pthread_mutex_lock(&b->lock);
	int phase = b->phase;
	int speech_answered = b->speech_answered;
	int speech_answer = b->speech_answer;
	int mic_answered = b->mic_answered;
	int mic_answer = b->mic_answer;
	pthread_mutex_unlock(&b->lock);
	if (phase == UI2_SP_WAIT_SPEECH) {
		long status = ui2_sp_speech_status();
		if (status == UI2_SP_SPEECH_AUTHORIZED
			|| (speech_answered && speech_answer == UI2_SP_SPEECH_AUTHORIZED)) {
			int problem = ui2_sp_ask_microphone(b);
			if (problem != UI2_SP_OK) ui2_sp_fail(b, problem);
		} else if (status == UI2_SP_SPEECH_DENIED_STATUS || (speech_answered
			&& speech_answer != UI2_SP_SPEECH_RESTRICTED_STATUS)) {
			ui2_sp_fail(b, UI2_SP_SPEECH_DENIED);
		} else if (status == UI2_SP_SPEECH_RESTRICTED_STATUS || speech_answered) {
			ui2_sp_fail(b, UI2_SP_SPEECH_RESTRICTED);
		}
	} else if (phase == UI2_SP_WAIT_MIC) {
		long status = ui2_sp_mic_status(b);
		if (status == UI2_SP_MIC_AUTHORIZED || (mic_answered && mic_answer)) {
			int problem = ui2_sp_begin(b);
			if (problem != UI2_SP_OK) ui2_sp_fail(b, problem);
		} else if (status == UI2_SP_MIC_RESTRICTED_STATUS) {
			ui2_sp_fail(b, UI2_SP_MICROPHONE_RESTRICTED);
		} else if (status == UI2_SP_MIC_DENIED_STATUS || mic_answered) {
			ui2_sp_fail(b, UI2_SP_MICROPHONE_DENIED);
		}
	}
}

// ui2_speech_stop ends capture; the final result follows as events. A session
// still waiting for access simply ends.
static void ui2_speech_stop(ui2_speech* b) {
	pthread_mutex_lock(&b->lock);
	int phase = b->phase;
	if (phase == UI2_SP_WAIT_SPEECH || phase == UI2_SP_WAIT_MIC) {
		b->phase = UI2_SP_IDLE;
		ui2_speech_event event;
		memset(&event, 0, sizeof(event));
		event.kind = UI2_SP_EVENT_DONE;
		event.success = 1;
		ui2_sp_push(b, event);
	}
	pthread_mutex_unlock(&b->lock);
	if (phase != UI2_SP_RUNNING) return;
	ui2_sp_stop_capture(b);
	void* pool = ui2_sp_pool_push();
	ui2_sp_send(b->request, "endAudio");
	ui2_sp_pool_pop(pool);
	pthread_mutex_lock(&b->lock);
	if (b->phase == UI2_SP_RUNNING) b->phase = UI2_SP_FINISHING;
	pthread_mutex_unlock(&b->lock);
}

// ui2_speech_cancel ends the session at once; nothing more is reported.
static void ui2_speech_cancel(ui2_speech* b) {
	pthread_mutex_lock(&b->lock);
	b->generation++;
	b->phase = UI2_SP_IDLE;
	ui2_sp_clear_events(b);
	pthread_mutex_unlock(&b->lock);
	// Once capture has stopped the input callback no longer reads the request.
	ui2_sp_stop_capture(b);
	void* pool = ui2_sp_pool_push();
	ui2_sp_release_session(b);
	ui2_sp_pool_pop(pool);
}

#endif
