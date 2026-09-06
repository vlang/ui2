# Bundled fonts

Roboto 3.016, the `web/static` build from
[googlefonts/roboto-classic](https://github.com/googlefonts/roboto-classic/releases/tag/v3.016),
covering Latin, Greek, Cyrillic, and Vietnamese, Roboto Mono 3.001 from
[googlefonts/RobotoMono](https://github.com/googlefonts/RobotoMono), and Noto
Sans Symbols 2 v2.008, the `unhinted` build from
[notofonts/symbols](https://github.com/notofonts/symbols/releases/tag/NotoSansSymbols2-v2.008).

The custom renderer draws with these files unless the application overrides them
(see "Fonts and text sizes" in the top-level README), so a `gg` window looks the
same on Linux, Android, and macOS or Windows built with `-d ui2_custom_rendering`.

`RobotoMono-Regular.ttf` has to keep that name and stay in this directory: gg
finds its mono face by rewriting `-Regular` to `Mono-Regular` in the path it was
given. It is also what an element asking for an unavailable fixed-pitch family,
such as `Consolas` or the generic `monospace`, falls back to.

`NotoSansSymbols2-Regular.ttf` is not drawn with directly; it is the first face
the renderer searches when the text font has no outline for a code point. Roboto
covers 927 of them, which is every letter an interface is written in and almost
none of the marks it labels rows with, so a ▸ or a ✓ would otherwise come
out as the empty box. Noto Sans Symbols 2 carries the geometric shapes, dingbats,
box elements and braille, and the renderer adds one symbol face off the machine
behind it for the blocks it leaves out, arrows among them. Nothing here covers
emoji: those need a color font, and `stb_truetype` rasterizes outlines only.

These are the static instances on purpose. `stb_truetype`, the rasterizer
fontstash builds with, ignores the `fvar` and `gvar` tables, so the variable
`Roboto[wdth,wght].ttf` would draw bold text at the regular weight.

For Roboto, the `web` build rather than `unhinted` because it is a third of the
size and carries the same outlines; `stb_truetype` never runs hinting
instructions, so the `hinted` build would only add bytes. For the same reason
Noto Sans Symbols 2 is the `unhinted` build rather than the `googlefonts` one,
which is the same outlines and twice the file.

All three families are licensed under the SIL Open Font License 1.1. They carry
different copyright notices, so each keeps its own copy: `Roboto-OFL.txt`,
`RobotoMono-OFL.txt` and `NotoSansSymbols2-OFL.txt`.
