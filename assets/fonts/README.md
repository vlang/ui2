# Bundled font

Roboto 3.016, the `web/static` build from
[googlefonts/roboto-classic](https://github.com/googlefonts/roboto-classic/releases/tag/v3.016),
covering Latin, Greek, Cyrillic, and Vietnamese.

The custom renderer draws with these files unless the application overrides them
(see "Fonts and text sizes" in the top-level README), so a `gg` window looks the
same on Linux, Android, and macOS or Windows built with `-d ui2_custom_rendering`.

They are the static instances on purpose. `stb_truetype`, the rasterizer
fontstash builds with, ignores the `fvar` and `gvar` tables, so the variable
`Roboto[wdth,wght].ttf` would draw bold text at the regular weight.

The `web` build rather than `unhinted` because it is a third of the size and
carries the same outlines; `stb_truetype` never runs hinting instructions, so
the `hinted` build would only add bytes.

Licensed under the SIL Open Font License 1.1, see `OFL.txt`.
