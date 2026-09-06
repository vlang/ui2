# Bundled fonts

Roboto 3.016, the `web/static` build from
[googlefonts/roboto-classic](https://github.com/googlefonts/roboto-classic/releases/tag/v3.016),
covering Latin, Greek, Cyrillic, and Vietnamese, and Roboto Mono 3.001 from
[googlefonts/RobotoMono](https://github.com/googlefonts/RobotoMono).

The custom renderer draws with these files unless the application overrides them
(see "Fonts and text sizes" in the top-level README), so a `gg` window looks the
same on Linux, Android, and macOS or Windows built with `-d ui2_custom_rendering`.

`RobotoMono-Regular.ttf` has to keep that name and stay in this directory: gg
finds its mono face by rewriting `-Regular` to `Mono-Regular` in the path it was
given. It is also what an element asking for an unavailable fixed-pitch family,
such as `Consolas` or the generic `monospace`, falls back to.

These are the static instances on purpose. `stb_truetype`, the rasterizer
fontstash builds with, ignores the `fvar` and `gvar` tables, so the variable
`Roboto[wdth,wght].ttf` would draw bold text at the regular weight.

For Roboto, the `web` build rather than `unhinted` because it is a third of the
size and carries the same outlines; `stb_truetype` never runs hinting
instructions, so the `hinted` build would only add bytes.

Both families are licensed under the SIL Open Font License 1.1. The two carry
different copyright notices, so each keeps its own copy: `Roboto-OFL.txt` and
`RobotoMono-OFL.txt`.
