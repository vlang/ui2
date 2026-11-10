// AVFoundation playback and capture for macOS and iOS. Sessions outlive
// their views the way the webview module's sessions outlive windows: closing
// detaches the layer, and the player is torn down only on close, so a view
// rebuilt around the same id keeps playing without a gap.
#import "media_apple.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@interface Ui2MediaSession : NSObject {
@public
	AVPlayer *player;
	AVQueuePlayer *queuePlayer;
	AVPlayerLooper *looper;
	AVPlayerLayer *layer;
	AVPlayerItem *item;
	AVAudioRecorder *recorder;
	NSString *source;
	NSString *kind;
	id endObserver;
	int pausedFlag;
	int loopFlag;
	int endedFlag;
	double rateValue;
	double volumeValue;
	int mutedFlag;
	NSDate *recordStart;
}
@end

@implementation Ui2MediaSession
- (void)dealloc {
	[self detachLayer];
	[player pause];
	[player release];
	[queuePlayer release];
	[looper release];
	[layer release];
	[item release];
	[recorder stop];
	[recorder release];
	[source release];
	[kind release];
	[recordStart release];
	[super dealloc];
}
- (void)detachLayer {
	if (endObserver != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver:endObserver];
		[endObserver release];
		endObserver = nil;
	}
	[layer removeFromSuperlayer];
	[layer release];
	layer = nil;
}
@end

// Sessions keyed by the ui2 element id. Main-thread only, like the rest of
// the native backends' element state.
static NSMutableDictionary *ui2_media_sessions(void) {
	static NSMutableDictionary *sessions = nil;
	if (sessions == nil) {
		sessions = [[NSMutableDictionary alloc] init];
	}
	return sessions;
}

static Ui2MediaSession *ui2_media_session(const char *cid) {
	if (cid == NULL) return nil;
	NSString *key = [NSString stringWithUTF8String:cid];
	return (Ui2MediaSession *)[ui2_media_sessions() objectForKey:key];
}

static NSURL *ui2_media_url(const char *src) {
	if (src == NULL) return nil;
	NSString *raw = [NSString stringWithUTF8String:src];
	NSString *lower = [raw lowercaseString];
	if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]
		|| [lower hasPrefix:@"rtsp://"]) {
		return [NSURL URLWithString:raw];
	}
	if ([lower hasPrefix:@"file://"]) {
		return [NSURL URLWithString:raw];
	}
	return [NSURL fileURLWithPath:raw];
}

// The container view a layer attaches to. Custom-rendered windows hand the
// NSWindow/UIWindow itself, whose content fills the same role.
static id ui2_media_container(void *parent) {
	id view = (id)parent;
	if (view == nil) return nil;
#if TARGET_OS_IPHONE
	if ([view isKindOfClass:[UIWindow class]]) {
		UIViewController *root = [(UIWindow *)view rootViewController];
		if (root != nil && root.view != nil) return root.view;
		return (id)[(UIWindow *)view layer];
	}
#else
	if ([view isKindOfClass:[NSWindow class]]) {
		return [(NSWindow *)view contentView];
	}
#endif
	return view;
}

void *ui2_media_apple_attach(const char *cid, void *parent) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil) return NULL;
		if (![session->kind isEqualToString:@"video"]) return (void *)session->player;
		id container = ui2_media_container(parent);
		if (container == nil) return NULL;
#if TARGET_OS_IPHONE
		if (![container isKindOfClass:[UIView class]]) return NULL;
#else
		if (![container isKindOfClass:[NSView class]]) return NULL;
#endif
		if (session->layer == nil) {
			session->layer = [[AVPlayerLayer playerLayerWithPlayer:session->player] retain];
			session->layer.videoGravity = AVLayerVideoGravityResizeAspect;
		} else if (session->layer.player != session->player) {
			session->layer.player = session->player;
		}
#if TARGET_OS_IPHONE
		CALayer *host = [(UIView *)container layer];
		CGRect frame = [(UIView *)container bounds];
#else
		NSView *hostView = (NSView *)container;
		[hostView setWantsLayer:YES];
		CALayer *host = [hostView layer];
		NSRect bounds = [hostView bounds];
		CGRect frame = NSRectToCGRect(bounds);
#endif
		if (session->layer.superlayer != host) {
			[session->layer removeFromSuperlayer];
			[host addSublayer:session->layer];
		}
		session->layer.frame = frame;
		return (void *)session->player;
	}
}

static void ui2_media_apple_rebuild_player(Ui2MediaSession *session) {
	if (session->item == nil) return;
	[session->player pause];
	[session->player release];
	session->player = nil;
	[session->queuePlayer release];
	session->queuePlayer = nil;
	[session->looper release];
	session->looper = nil;
	if (session->loopFlag) {
		AVQueuePlayer *queue = [[AVQueuePlayer alloc] initWithItems:@[ session->item ]];
		AVPlayerLooper *looper = [[AVPlayerLooper alloc] initWithPlayer:queue
														   templateItem:session->item];
		session->player = [queue retain];
		[queue release];
		session->queuePlayer = [queue retain];
		[queue release];
		session->looper = [looper retain];
		[looper release];
	} else {
		AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:session->item];
		session->player = [player retain];
		[player release];
		[session->queuePlayer release];
		session->queuePlayer = nil;
		[session->looper release];
		session->looper = nil;
	}
	session->player.volume = (float)session->volumeValue;
#if !TARGET_OS_IPHONE
	session->player.muted = session->mutedFlag ? YES : NO;
#else
	session->player.muted = session->mutedFlag ? YES : NO;
#endif
	if (session->layer != nil) {
		session->layer.player = session->player;
	}
}

static void ui2_media_apple_watch_end(Ui2MediaSession *session) {
	if (session->endObserver != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver:session->endObserver];
		[session->endObserver release];
		session->endObserver = nil;
	}
	if (session->loopFlag || session->item == nil) return;
	id token = [[NSNotificationCenter defaultCenter]
		addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
					object:session->item
					 queue:nil
				usingBlock:^(NSNotification *note) {
				  (void)note;
				  session->endedFlag = 1;
				}];
	session->endObserver = [token retain];
}

int ui2_media_apple_open(const char *cid, const char *kind, const char *src) {
	@autoreleasepool {
		if (cid == NULL || src == NULL) return 0;
		NSMutableDictionary *sessions = ui2_media_sessions();
		NSString *key = [NSString stringWithUTF8String:cid];
		NSString *wantedSource = [NSString stringWithUTF8String:src];
		NSString *wantedKind = [NSString stringWithUTF8String:kind];
		Ui2MediaSession *session = (Ui2MediaSession *)[sessions objectForKey:key];
		if (session != nil && [session->source isEqualToString:wantedSource]
			&& [session->kind isEqualToString:wantedKind] && session->player != nil) {
			return 1;
		}
		if (session != nil) {
			[session retain];
			[sessions removeObjectForKey:key];
			[session detachLayer];
			[session->player pause];
			[session release];
		}
		session = [[Ui2MediaSession alloc] init];
		session->source = [wantedSource retain];
		session->kind = [wantedKind retain];
		session->rateValue = 1.0;
		session->volumeValue = 1.0;
		NSURL *url = ui2_media_url(src);
		if (url == nil) {
			[session release];
			return 0;
		}
		AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
		session->item = [item retain];
		[item release];
		ui2_media_apple_rebuild_player(session);
		ui2_media_apple_watch_end(session);
		if (session->player == nil) {
			[session release];
			return 0;
		}
		[sessions setObject:session forKey:key];
		[session release];
		return 1;
	}
}

void ui2_media_apple_play(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil) return;
		session->endedFlag = 0;
		session->pausedFlag = 0;
		session->player.rate = (float)session->rateValue;
		if (session->player.rate == 0.0f) {
			[session->player play];
		}
	}
}

void ui2_media_apple_pause(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil) return;
		[session->player pause];
		session->pausedFlag = 1;
	}
}

void ui2_media_apple_stop(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil) return;
		[session->player pause];
		[session->player seekToTime:kCMTimeZero];
		session->pausedFlag = 0;
		session->endedFlag = 0;
	}
}

void ui2_media_apple_seek(const char *cid, double secs) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil) return;
		if (secs < 0) return;
		[session->player
			seekToTime:CMTimeMakeWithSeconds(secs, 600)
	   toleranceBefore:kCMTimeZero
		toleranceAfter:kCMTimeZero];
		session->endedFlag = 0;
	}
}

void ui2_media_apple_set_volume(const char *cid, double volume) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil) return;
		if (volume < 0) volume = 0;
		if (volume > 1) volume = 1;
		session->volumeValue = volume;
		if (session->player != nil) {
			session->player.volume = (float)volume;
		}
	}
}

void ui2_media_apple_set_mute(const char *cid, int muted) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil) return;
		session->mutedFlag = muted ? 1 : 0;
		if (session->player != nil) {
			session->player.muted = muted ? YES : NO;
		}
	}
}

void ui2_media_apple_set_rate(const char *cid, double rate) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || rate <= 0) return;
		session->rateValue = rate;
		if (session->player != nil && session->player.rate != 0.0f) {
			session->player.rate = (float)rate;
		}
	}
}

void ui2_media_apple_set_loop(const char *cid, int loop) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil) return;
		session->loopFlag = loop ? 1 : 0;
		ui2_media_apple_rebuild_player(session);
		ui2_media_apple_watch_end(session);
	}
}

void ui2_media_apple_close(const char *cid) {
	@autoreleasepool {
		if (cid == NULL) return;
		NSString *key = [NSString stringWithUTF8String:cid];
		Ui2MediaSession *session = (Ui2MediaSession *)[ui2_media_sessions() objectForKey:key];
		if (session == nil) return;
		[session retain];
		[ui2_media_sessions() removeObjectForKey:key];
		[session detachLayer];
		[session->player pause];
		[session->recorder stop];
		[session release];
	}
}

double ui2_media_apple_position(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil || session->player.currentItem == nil) {
			return -1.0;
		}
		double secs = CMTimeGetSeconds(session->player.currentTime);
		if (secs != secs) return -1.0;
		return secs < 0 ? 0.0 : secs;
	}
}

double ui2_media_apple_duration(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil || session->player.currentItem == nil) {
			return -1.0;
		}
		double secs = CMTimeGetSeconds(session->player.currentItem.duration);
		if (secs != secs || secs < 0) return -1.0;
		return secs;
	}
}

int ui2_media_apple_state(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil) return 0;
		if (session->recorder != nil && [session->recorder isRecording]) return 7;
		if (session->player == nil) return 0;
		if (session->endedFlag) return 5;
		if (session->player.rate != 0.0f) return 2;
		if (session->pausedFlag) return 3;
		return 4;
	}
}

int ui2_media_apple_can_seek(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->player == nil || session->player.currentItem == nil) {
			return 0;
		}
		return 1;
	}
}

int ui2_media_apple_record_start(const char *cid, const char *path) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || path == NULL) return 0;
		NSString *outPath = [NSString stringWithUTF8String:path];
		if (outPath == nil || [outPath length] == 0) return 0;
#if TARGET_OS_IPHONE
		AVAudioSession *audioSession = [AVAudioSession sharedInstance];
		NSError *sessionError = nil;
		[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
		if (sessionError != nil) return 0;
		[audioSession setActive:YES error:&sessionError];
		if (sessionError != nil) return 0;
#endif
		NSDictionary *settings = @{
			AVFormatIDKey : @(kAudioFormatLinearPCM),
			AVSampleRateKey : @44100.0,
			AVNumberOfChannelsKey : @1,
			AVLinearPCMBitDepthKey : @16,
			AVLinearPCMIsBigEndianKey : @NO,
			AVLinearPCMIsFloatKey : @NO
		};
		NSURL *url = [NSURL fileURLWithPath:outPath];
		NSError *error = nil;
		AVAudioRecorder *recorder =
			[[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
		if (recorder == nil || error != nil) {
			[recorder release];
			return 0;
		}
		if (![recorder record]) {
			[recorder release];
			return 0;
		}
		[session->recorder stop];
		[session->recorder release];
		session->recorder = [recorder retain];
		[recorder release];
		session->recordStart = [[NSDate date] retain];
		return 1;
	}
}

int ui2_media_apple_record_stop(const char *cid) {
	@autoreleasepool {
		Ui2MediaSession *session = ui2_media_session(cid);
		if (session == nil || session->recorder == nil) return 0;
		[session->recorder stop];
		return 1;
	}
}
