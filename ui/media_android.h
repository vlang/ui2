// Android media through OpenSL ES (NDK, no JVM needed): URI audio playback
// plus AAC/AMR microphone recording. Video has no NDK surface this layer
// can reach without a JVM callback, so it reports unsupported.
#ifndef UI2_MEDIA_ANDROID_H
#define UI2_MEDIA_ANDROID_H

#include <SLES/OpenSLES.h>
#include <SLES/OpenSLES_Android.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define UI2_MEDIA_ANDROID_MAX 16
#define UI2_MEDIA_ANDROID_PATH 1024

typedef struct {
	int used;
	char id[128];
	int kind;
	SLObjectItf player_obj;
	SLPlayItf player;
	SLSeekItf seek;
	SLVolumeItf volume;
	SLPlaybackRateItf rate;
	int has_rate;
	SLObjectItf recorder_obj;
	SLRecordItf recorder;
	int recording;
	int state;
	char src[UI2_MEDIA_ANDROID_PATH];
	int src_set;
} Ui2MediaAndroid;

static Ui2MediaAndroid ui2_media_android_sessions[UI2_MEDIA_ANDROID_MAX];
static SLObjectItf ui2_media_android_engine_obj = NULL;
static SLEngineItf ui2_media_android_engine = NULL;
static SLObjectItf ui2_media_android_mix_obj = NULL;

static int ui2_media_android_engine_ready(void) {
	SLresult res;
	if (ui2_media_android_engine != NULL) return 1;
	res = slCreateEngine(&ui2_media_android_engine_obj, 0, NULL, 0, NULL, NULL);
	if (res != SL_RESULT_SUCCESS) return 0;
	res = (*ui2_media_android_engine_obj)->Realize(ui2_media_android_engine_obj, SL_BOOLEAN_FALSE);
	if (res != SL_RESULT_SUCCESS) return 0;
	res = (*ui2_media_android_engine_obj)->GetInterface(ui2_media_android_engine_obj,
			SL_IID_ENGINE, &ui2_media_android_engine);
	if (res != SL_RESULT_SUCCESS || ui2_media_android_engine == NULL) return 0;
	res = (*ui2_media_android_engine)->CreateOutputMix(ui2_media_android_engine,
			&ui2_media_android_mix_obj, 0, NULL, NULL);
	if (res != SL_RESULT_SUCCESS) return 0;
	res = (*ui2_media_android_mix_obj)->Realize(ui2_media_android_mix_obj, SL_BOOLEAN_FALSE);
	return res == SL_RESULT_SUCCESS;
}

static Ui2MediaAndroid *ui2_media_android_find(const char *id) {
	int i;
	if (id == NULL) return NULL;
	for (i = 0; i < UI2_MEDIA_ANDROID_MAX; i++) {
		if (ui2_media_android_sessions[i].used
			&& strncmp(ui2_media_android_sessions[i].id, id, sizeof(ui2_media_android_sessions[i].id)) == 0) {
			return &ui2_media_android_sessions[i];
		}
	}
	return NULL;
}

static Ui2MediaAndroid *ui2_media_android_alloc(const char *id) {
	int i;
	Ui2MediaAndroid *slot;
	if (id == NULL) return NULL;
	slot = ui2_media_android_find(id);
	if (slot != NULL) return slot;
	for (i = 0; i < UI2_MEDIA_ANDROID_MAX; i++) {
		if (!ui2_media_android_sessions[i].used) {
			memset(&ui2_media_android_sessions[i], 0, sizeof(Ui2MediaAndroid));
			ui2_media_android_sessions[i].used = 1;
			strncpy(ui2_media_android_sessions[i].id, id,
				sizeof(ui2_media_android_sessions[i].id) - 1);
			return &ui2_media_android_sessions[i];
		}
	}
	return NULL;
}

static void ui2_media_android_destroy_player(Ui2MediaAndroid *s) {
	if (s->player_obj != NULL) {
		(*s->player_obj)->Destroy(s->player_obj);
		s->player_obj = NULL;
	}
	s->player = NULL;
	s->seek = NULL;
	s->volume = NULL;
	s->rate = NULL;
	s->has_rate = 0;
}

static void ui2_media_android_destroy_recorder(Ui2MediaAndroid *s) {
	if (s->recorder_obj != NULL) {
		(*s->recorder_obj)->Destroy(s->recorder_obj);
		s->recorder_obj = NULL;
	}
	s->recorder = NULL;
	s->recording = 0;
}

// Container and MIME picked from the extension; anything else is refused so
// a mislabeled stream fails fast instead of stalling inside stagefright.
static int ui2_media_android_play_format(const char *src, SLuint32 *container, const char **mime) {
	size_t n;
	const char *dot;
	if (src == NULL) return 0;
	n = strlen(src);
	dot = n > 4 ? src + n - 4 : src;
	if (strncasecmp(dot, ".mp3", 4) == 0) {
		*container = SL_CONTAINERTYPE_MP3;
		*mime = "audio/mpeg";
		return 1;
	}
	if (strncasecmp(dot, ".wav", 4) == 0) {
		*container = SL_CONTAINERTYPE_WAV;
		*mime = "audio/x-wav";
		return 1;
	}
	if (strncasecmp(dot, ".m4a", 4) == 0 || strncasecmp(dot, ".mp4", 4) == 0) {
		*container = SL_CONTAINERTYPE_MP4;
		*mime = "audio/mp4";
		return 1;
	}
	if (strncasecmp(dot, ".aac", 4) == 0) {
		*container = SL_CONTAINERTYPE_AAC;
		*mime = "audio/aac";
		return 1;
	}
	return 0;
}

static int ui2_media_android_open(const char *id, const char *src) {
	Ui2MediaAndroid *s;
	SLDataLocator_URI loc_uri;
	SLDataFormat_MIME fmt;
	SLDataSource audio_src;
	SLDataLocator_OutputMix loc_mix;
	SLDataSink audio_sink;
	SLInterfaceID ids[3];
	SLboolean req[3];
	SLresult res;
	SLuint32 container;
	const char *mime;
	if (!ui2_media_android_engine_ready()) return 0;
	s = ui2_media_android_alloc(id);
	if (s == NULL) return 0;
	if (!ui2_media_android_play_format(src, &container, &mime)) return 0;
	ui2_media_android_destroy_player(s);
	loc_uri.locatorType = SL_DATALOCATOR_URI;
	loc_uri.URI = (SLchar *)src;
	fmt.formatType = SL_DATAFORMAT_MIME;
	fmt.mimeType = (SLchar *)mime;
	fmt.containerType = container;
	audio_src.pLocator = &loc_uri;
	audio_src.pFormat = &fmt;
	loc_mix.locatorType = SL_DATALOCATOR_OUTPUTMIX;
	loc_mix.outputMix = ui2_media_android_mix_obj;
	audio_sink.pLocator = &loc_mix;
	audio_sink.pFormat = NULL;
	ids[0] = SL_IID_PLAY;
	ids[1] = SL_IID_SEEK;
	ids[2] = SL_IID_VOLUME;
	req[0] = SL_BOOLEAN_TRUE;
	req[1] = SL_BOOLEAN_TRUE;
	req[2] = SL_BOOLEAN_TRUE;
	res = (*ui2_media_android_engine)->CreateAudioPlayer(ui2_media_android_engine,
		&s->player_obj, &audio_src, &audio_sink, 3, ids, req);
	if (res != SL_RESULT_SUCCESS || s->player_obj == NULL) return 0;
	res = (*s->player_obj)->Realize(s->player_obj, SL_BOOLEAN_FALSE);
	if (res != SL_RESULT_SUCCESS) {
		ui2_media_android_destroy_player(s);
		return 0;
	}
	res = (*s->player_obj)->GetInterface(s->player_obj, SL_IID_PLAY, &s->player);
	if (res != SL_RESULT_SUCCESS || s->player == NULL) {
		ui2_media_android_destroy_player(s);
		return 0;
	}
	if ((*s->player_obj)->GetInterface(s->player_obj, SL_IID_SEEK, &s->seek)
		== SL_RESULT_SUCCESS) {
	} else {
		s->seek = NULL;
	}
	if ((*s->player_obj)->GetInterface(s->player_obj, SL_IID_VOLUME, &s->volume)
		!= SL_RESULT_SUCCESS) {
		s->volume = NULL;
	}
	if ((*s->player_obj)->GetInterface(s->player_obj, SL_IID_RATE, &s->rate)
		== SL_RESULT_SUCCESS) {
		s->has_rate = 1;
	}
	strncpy(s->src, src, sizeof(s->src) - 1);
	s->src_set = 1;
	s->state = 4;
	return 1;
}

static int ui2_media_android_play(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	SLresult res;
	if (s == NULL || s->player == NULL) return 0;
	res = (*s->player)->SetPlayState(s->player, SL_PLAYSTATE_PLAYING);
	if (res != SL_RESULT_SUCCESS) return 0;
	s->state = 2;
	return 1;
}

static int ui2_media_android_pause(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	SLresult res;
	if (s == NULL || s->player == NULL) return 0;
	res = (*s->player)->SetPlayState(s->player, SL_PLAYSTATE_PAUSED);
	if (res != SL_RESULT_SUCCESS) return 0;
	s->state = 3;
	return 1;
}

static int ui2_media_android_stop(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	SLresult res;
	if (s == NULL || s->player == NULL) return 0;
	res = (*s->player)->SetPlayState(s->player, SL_PLAYSTATE_STOPPED);
	if (res != SL_RESULT_SUCCESS) return 0;
	if (s->seek != NULL) {
		(*s->seek)->SetPosition(s->seek, 0, SL_SEEKMODE_FAST);
	}
	s->state = 4;
	return 1;
}

static int ui2_media_android_seek(const char *id, int ms) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL || s->seek == NULL || ms < 0) return 0;
	return (*s->seek)->SetPosition(s->seek, (SLmillisecond)ms, SL_SEEKMODE_ACCURATE)
		== SL_RESULT_SUCCESS;
}

static int ui2_media_android_set_volume_db(const char *id, int millibel) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL || s->volume == NULL) return 0;
	return (*s->volume)->SetVolumeLevel(s->volume, (SLmillibel)millibel)
		== SL_RESULT_SUCCESS;
}

static int ui2_media_android_set_mute(const char *id, int muted) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL || s->volume == NULL) return 0;
	return (*s->volume)->SetMute(s->volume, muted ? SL_BOOLEAN_TRUE : SL_BOOLEAN_FALSE)
		== SL_RESULT_SUCCESS;
}

static int ui2_media_android_set_rate(const char *id, int per_mille) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL || !s->has_rate || s->rate == NULL || per_mille <= 0) return 0;
	return (*s->rate)->SetRate(s->rate, (SLpermille)per_mille) == SL_RESULT_SUCCESS;
}

static int ui2_media_android_position_ms(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	SLmillisecond pos = 0;
	if (s == NULL || s->player == NULL) return -1;
	if ((*s->player)->GetPosition(s->player, &pos) != SL_RESULT_SUCCESS) return -1;
	return (int)pos;
}

static int ui2_media_android_state(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL) return 0;
	if (s->recording) return 7;
	return s->state;
}

static void ui2_media_android_close(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL) return;
	ui2_media_android_destroy_player(s);
	ui2_media_android_destroy_recorder(s);
	s->used = 0;
	s->state = 0;
	s->src_set = 0;
}

// AAC in MP4 (.m4a/.mp4) or AMR in 3GP (.3gp/.amr): the containers Android's
// OpenSL recorder drains to without a JVM encoder.
static int ui2_media_android_record_format(const char *path, SLuint32 *container, const char **mime) {
	size_t n = path != NULL ? strlen(path) : 0;
	if (n > 4 && (strncasecmp(path + n - 4, ".m4a", 4) == 0
			|| strncasecmp(path + n - 4, ".mp4", 4) == 0)) {
		*container = SL_CONTAINERTYPE_MP4;
		*mime = "audio/mp4a-latm";
		return 1;
	}
	if (n > 4 && (strncasecmp(path + n - 4, ".3gp", 4) == 0
			|| strncasecmp(path + n - 4, ".amr", 4) == 0)) {
		*container = SL_CONTAINERTYPE_3GPP;
		*mime = "audio/3gpp";
		return 1;
	}
	return 0;
}

static int ui2_media_android_record_start(const char *id, const char *path) {
	Ui2MediaAndroid *s;
	SLDataLocator_IODevice loc_dev;
	SLDataSource audio_src;
	SLDataLocator_URI loc_uri;
	SLDataFormat_MIME fmt;
	SLDataSink audio_sink;
	SLInterfaceID rec_id;
	SLboolean rec_req;
	SLresult res;
	SLuint32 container;
	const char *mime;
	if (!ui2_media_android_engine_ready()) return 0;
	s = ui2_media_android_alloc(id);
	if (s == NULL) return 0;
	if (!ui2_media_android_record_format(path, &container, &mime)) return 0;
	ui2_media_android_destroy_recorder(s);
	loc_dev.locatorType = SL_DATALOCATOR_IODEVICE;
	loc_dev.deviceType = SL_IODEVICE_AUDIOINPUT;
	loc_dev.deviceID = SL_DEFAULTDEVICEID_AUDIOINPUT;
	loc_dev.device = NULL;
	audio_src.pLocator = &loc_dev;
	audio_src.pFormat = NULL;
	loc_uri.locatorType = SL_DATALOCATOR_URI;
	loc_uri.URI = (SLchar *)path;
	fmt.formatType = SL_DATAFORMAT_MIME;
	fmt.mimeType = (SLchar *)mime;
	fmt.containerType = container;
	audio_sink.pLocator = &loc_uri;
	audio_sink.pFormat = &fmt;
	rec_id = SL_IID_RECORD;
	rec_req = SL_BOOLEAN_TRUE;
	res = (*ui2_media_android_engine)->CreateAudioRecorder(ui2_media_android_engine,
		&s->recorder_obj, &audio_src, &audio_sink, 1, &rec_id, &rec_req);
	if (res != SL_RESULT_SUCCESS || s->recorder_obj == NULL) return 0;
	res = (*s->recorder_obj)->Realize(s->recorder_obj, SL_BOOLEAN_FALSE);
	if (res != SL_RESULT_SUCCESS) {
		ui2_media_android_destroy_recorder(s);
		return 0;
	}
	res = (*s->recorder_obj)->GetInterface(s->recorder_obj, SL_IID_RECORD, &s->recorder);
	if (res != SL_RESULT_SUCCESS || s->recorder == NULL) {
		ui2_media_android_destroy_recorder(s);
		return 0;
	}
	res = (*s->recorder)->SetRecordState(s->recorder, SL_RECORDSTATE_RECORDING);
	if (res != SL_RESULT_SUCCESS) {
		ui2_media_android_destroy_recorder(s);
		return 0;
	}
	s->recording = 1;
	return 1;
}

static int ui2_media_android_record_stop(const char *id) {
	Ui2MediaAndroid *s = ui2_media_android_find(id);
	if (s == NULL || s->recorder == NULL || !s->recording) return 0;
	(*s->recorder)->SetRecordState(s->recorder, SL_RECORDSTATE_STOPPED);
	ui2_media_android_destroy_recorder(s);
	return 1;
}

#endif
