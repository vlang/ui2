// Shared AVFoundation bridge for macOS and iOS (media_apple.m implements
// it). One C entry point per media operation; sessions live in an
// NSMutableDictionary keyed by the ui2 element id. Manual retain/release to
// match the -fno-objc-arc build flag.
#ifndef UI2_MEDIA_APPLE_H
#define UI2_MEDIA_APPLE_H

#ifdef __cplusplus
extern "C" {
#endif

// Playback. parent is the container NSView/UIView, or the NSWindow/UIWindow
// for custom-rendered windows (resolved to its content view inside).
int ui2_media_apple_open(const char *cid, const char *kind, const char *src);
void *ui2_media_apple_attach(const char *cid, void *parent);
void ui2_media_apple_play(const char *cid);
void ui2_media_apple_pause(const char *cid);
void ui2_media_apple_stop(const char *cid);
void ui2_media_apple_seek(const char *cid, double secs);
void ui2_media_apple_set_volume(const char *cid, double volume);
void ui2_media_apple_set_mute(const char *cid, int muted);
void ui2_media_apple_set_rate(const char *cid, double rate);
void ui2_media_apple_set_loop(const char *cid, int loop);
void ui2_media_apple_close(const char *cid);
double ui2_media_apple_position(const char *cid);
double ui2_media_apple_duration(const char *cid);
// 0 idle, 1 loading, 2 playing, 3 paused, 4 stopped, 5 ended, 6 error,
// 7 recording. Matches ui2.MediaState order.
int ui2_media_apple_state(const char *cid);
int ui2_media_apple_can_seek(const char *cid);

// Recording. WAV (LinearPCM 44.1kHz mono) to output_path.
int ui2_media_apple_record_start(const char *cid, const char *path);
int ui2_media_apple_record_stop(const char *cid);

#ifdef __cplusplus
}
#endif

#endif
