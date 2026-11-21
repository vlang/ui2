# Media: audio, video and capture inputs

HTML5-like media on every backend, using only each platform's built-in
capabilities. No mpv, VLC, ffmpeg or any other third-party media library is
ever needed (nor linked).

A `media` element names the source declaratively; transport runs through
small imperative calls keyed by the element id — the same controlled
pattern `text_field` and `slider` use. Position, duration and state are
pulled by the application, usually on a timer tick, so every backend
behaves the same without event plumbing:

```v
audio('theme', 'assets/theme.mp3')
video('intro', 'https://example.com/intro.mp4', ui2.rect(20, 100, 320, 180))
media_controls(id: 'intro', frame: ui2.rect(20, 290, 320, 40))

fn on_event(mut app App, e string) {
    if ui2.media_handle_control('intro', e) {
        // play / pause / seek / mute consumed; rebuild to repaint.
    }
    ui2.refresh()
}
```

## What runs where

| Capability | Windows | macOS | iOS | Android | Linux / BSD |
|---|---|---|---|---|---|
| Audio playback | MCI (any format) | AVFoundation | AVFoundation | OpenSL ES | WAV via helper tools |
| Video playback | MCI child window | AVPlayerLayer subview | AVPlayerLayer subview | unsupported | unsupported |
| Seek / position / duration | yes | yes | yes | seek only, no duration | no |
| Microphone recording | MCI → WAV | AVAudioRecorder → WAV | AVAudioRecorder → WAV | OpenSL → AAC/AMR | `arecord`/`parecord` → WAV |
| Screen snapshot | GDI → BMP | `screencapture` → PNG | unsupported | unsupported | `grim`/`gnome-screenshot`/`scrot`/`import` → PNG, if installed |

Use `media_playback_supported(kind)` and `media_capture_supported(source)`
to adapt the UI: unsupported inputs report `false` instead of failing, and
the `media_recorder` component disables itself where recording is missing.

Linux helpers are probed at runtime (`aplay`/`paplay`/`pw-play` for sound):
installing none of them only disables playback. Video has no platform
decoder there, so video elements show their placeholder and report an
unsupported-source error.

## Playback

```v
ui2.media(id: 'clip', kind: .video, source: .url, src: url, frame: f, autoplay: true, loop: true)!
```

- `src` is a file path or URL; `media_source_for_src` guesses `.url` from
  `http(s)://` and `rtsp(s)://` prefixes.
- `media_open` preloads a session for element-less (background audio) use;
  otherwise the first rendered frame opens it from the declaration.
- `media_play`, `media_pause`, `media_toggle`, `media_stop` (pause + rewind),
  `media_seek(id, secs)`, `media_set_volume` (0..1, clamped),
  `media_set_muted`, `media_set_rate` (1 is normal speed),
  `media_set_loop`, `media_close`.
- `media_position` / `media_duration` return seconds, or `-1` while unknown
  (live streams, CLI playback). `media_state` settles a finished track:
  looping restarts it, otherwise it reports `.ended`.
- `media_time_format` renders `m:ss` / `h:mm:ss` (`--:--` for unknown).
- `media_can_seek` tells the seek slider whether dragging does anything.

Video draws into a native child surface parented to the element: an MCI
child window on Windows, an `AVPlayerLayer` sublayer on macOS/iOS, a
positioned overlay on the custom renderer. The declarative frame owns the
picture's rectangle; borders and layout behave like any other element, and
`media_end_frame` detaches surfaces whose element left the tree.

## Recording and snapshots

```v
ui2.media_recorder(id: 'memo', output_path: path, frame: f)!
ui2.media_start_recording('memo', .microphone, path)
ui2.media_stop_recording('memo')
ui2.media_recording_elapsed('memo') // seconds, or -1
ui2.media_capture_screen(path) // one-shot PNG (BMP on Windows)
```

Only `.microphone` records into a session; snapshots are one-shot calls.
Screen capture needs no element at all — wire any button to
`media_capture_screen`. macOS may prompt for Screen Recording permission on
first use; iOS needs the microphone usage description for recording.

## VML and the C API

`<Video source="…" autoplay loop />` and `<Audio source="…" />` map to the
same builders, with `muted`, `volume` and `rate` attributes. The C API
accepts the `UI2_MEDIA` kind through the generic `ui2_create` entry point.
