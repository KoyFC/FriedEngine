# UI measurements

A screen of 36 buttons in three columns, a header, and 80 elements in all (`bench/ui.hxml`, 223 draw commands), in melonDS, with `-D fried_profile`. `uistyle` is the time to work out the style of what changed, `uilayout` the layout, and `d` the whole draw step, which holds both. Each frame toggles a class on one button, and by default also rewrites a text.

| Version | uistyle | uilayout | d |
|---|---|---|---|
| First (floats, text measured on every layout) | 0.76 ms | 13.58 ms | 20.5 ms |
| Text measures kept | 0.74 ms | 6.67 ms | 13.67 ms |
| Whole numbers, no arrays in the layout, rules indexed, font kept, paint-only changes skip the layout | 0.33 ms | 1.61 ms | 3.96 ms |
| Same, class change only (`-D ui_paint`) | 0.27 ms | 0 | 2.28 ms |
| Same, nothing changes (`-D ui_static`) | 0 | 0 | 1.99 ms |

The frame holds 60 fps in all three last cases. A document that does not change costs 2 ms to draw, which is the 223 commands it submits, about 9 microseconds each. A hover or a press costs 0.3 ms, and a text whose size changes costs a layout of the whole document, 1.6 ms for these 80 elements, so a HUD with a few elements and a counter costs a fraction of that.

Two things measured on the way: a rectangle outline (`submitRect`) costs the DS about 150 microseconds, much more than the four filled rectangles that draw the same border, so borders are four fills; and `EReg` (Haxe's `Xml` uses one) does not build for the DS.

## Rounded corners, gradients and shadows

The same screen, with nothing changing, against the 1.99 ms of drawing and 223 commands it takes plain:

| Decoration of the 36 buttons | commands | d |
|---|---|---|
| Corners of 6 px (fans of 4 triangles) | 331 | 42.2 ms (15 fps) |
| A gradient of 8 bands and a hard shadow | 511 | 4.18 ms |

The corners go through arrays of floats that the draw queue copies, which on a chip with no floating point unit costs about 0.4 ms for each box. The gradient and the shadow only add rectangles, 2.2 ms more for 36 buttons. Both are far over what a frame can spare, so on the DS and the fx-CG50 a box is drawn plain, and other platforms draw them live. What would make them cheap there is the editor or `fried_import` baking each radius, border, gradient and shadow of a sheet into a nine-slice picture that `submitTexture` draws in nine commands, chosen by a `"ui": {"bake": true}` in the sidecar of the sheet. That is not built.
