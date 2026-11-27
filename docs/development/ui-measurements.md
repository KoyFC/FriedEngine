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
