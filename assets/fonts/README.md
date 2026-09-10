# Bundled fonts

Roboto 3.016, the `web/static` build from
[googlefonts/roboto-classic](https://github.com/googlefonts/roboto-classic/releases/tag/v3.016),
covering Latin, Greek, Cyrillic, and Vietnamese, Roboto Mono 3.001 from
[googlefonts/RobotoMono](https://github.com/googlefonts/RobotoMono), Material
Icons from [google/material-design-icons](https://github.com/google/material-design-icons),
Noto Sans Symbols 2 v2.008, the `unhinted` build from
[notofonts/symbols](https://github.com/notofonts/symbols/releases/tag/NotoSansSymbols2-v2.008),
and Noto Emoji 3.002 from
[google/fonts](https://github.com/google/fonts/tree/main/ofl/notoemoji).

The custom renderer draws with these files unless the application overrides them
(see "Fonts and text sizes" in the top-level README), so a `gg` window looks the
same on Linux, Android, and macOS or Windows built with `-d ui2_custom_rendering`.

`RobotoMono-Regular.ttf` has to keep that name and stay in this directory: gg
finds its mono face by rewriting `-Regular` to `Mono-Regular` in the path it was
given. It is also what an element asking for an unavailable fixed-pitch family,
such as `Consolas` or the generic `monospace`, falls back to.

`MaterialIcons-Regular.ttf` supplies portable equivalents for platform icon
names such as SF Symbols on a custom-rendered desktop. It is also at the front
of the fallback chain so its private-use glyphs can be drawn without depending
on a machine-installed icon font.

`NotoSansSymbols2-Regular.ttf` is not drawn with directly; it follows Material
Icons in the fallback chain and is the first general-purpose symbol face
the renderer searches when the text font has no outline for a code point. Roboto
covers 927 of them, which is every letter an interface is written in and almost
none of the marks it labels rows with, so a ▸ or a ✓ would otherwise come
out as the empty box. Noto Sans Symbols 2 carries the geometric shapes, dingbats,
box elements and braille, and the renderer adds one symbol face off the machine
behind it for the blocks it leaves out, arrows among them.

`NotoEmoji-Regular.ttf` sits behind it in that same chain and is what draws an
emoji. It is the monochrome Noto Emoji, not the color one: `stb_truetype` reads
neither the bitmaps of `NotoColorEmoji.ttf` nor the layers of a COLR font, and
the outline such a face leaves at the base glyph is empty, so it would trade the
empty box for an empty space. Monochrome emoji are outlines like any other
glyph, and they take the color the label was given. The file also carries U+FE0F
and U+200D, the variation selector and the joiner that emoji are written with,
which would otherwise draw a box of their own — the renderer does no shaping, so
it draws every code point it is handed.

Upstream ships the monochrome family as the variable `NotoEmoji[wght].ttf`
only, which is the one thing this directory cannot use, so the file here is its
regular instance:

```sh
fonttools varLib.instancer -q 'NotoEmoji[wght].ttf' wght=400 \
	--update-name-table -o NotoEmoji-Regular.ttf
```

These are the static instances on purpose. `stb_truetype`, the rasterizer
fontstash builds with, ignores the `fvar` and `gvar` tables, so the variable
`Roboto[wdth,wght].ttf` would draw bold text at the regular weight.

For Roboto, the `web` build rather than `unhinted` because it is a third of the
size and carries the same outlines; `stb_truetype` never runs hinting
instructions, so the `hinted` build would only add bytes. For the same reason
Noto Sans Symbols 2 is the `unhinted` build rather than the `googlefonts` one,
which is the same outlines and twice the file.

Roboto, Roboto Mono, Noto Sans Symbols 2, and Noto Emoji are licensed under the
SIL Open Font License 1.1. They carry
different copyright notices, so each keeps its own copy: `Roboto-OFL.txt`,
`RobotoMono-OFL.txt`, `NotoSansSymbols2-OFL.txt` and `NotoEmoji-OFL.txt`.
Material Icons is licensed under Apache License 2.0, kept as
`MaterialIcons-LICENSE.txt`.
