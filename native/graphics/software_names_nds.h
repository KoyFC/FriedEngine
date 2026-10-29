#pragma once

// Forced into renderer_software.cpp and texture_software.cpp on the DS, ahead
// of everything else in them, where they draw the bottom screen behind the 3D
// engine's renderer. Their entry points take names of their own here, which
// renderer_nds.cpp and texture_nds.cpp hand the bottom screen's calls to, so
// both can be linked into one program with the calculator's files unchanged.
// Each side numbers its renderers and textures from zero; the public ids the
// two DS files give out keep them apart.

#define fried_renderer_clear fried_software_renderer_clear
#define fried_renderer_create fried_software_renderer_create
#define fried_renderer_destroy fried_software_renderer_destroy
#define fried_renderer_draw_glyphs fried_software_renderer_draw_glyphs
#define fried_renderer_draw_rect fried_software_renderer_draw_rect
#define fried_renderer_draw_texture fried_software_renderer_draw_texture
#define fried_renderer_draw_texture_ex fried_software_renderer_draw_texture_ex
#define fried_renderer_draw_tinted fried_software_renderer_draw_tinted
#define fried_renderer_fill_rect fried_software_renderer_fill_rect
#define fried_renderer_fill_triangles fried_software_renderer_fill_triangles
#define fried_renderer_get_height fried_software_renderer_get_height
#define fried_renderer_get_pixel_scale fried_software_renderer_get_pixel_scale
#define fried_renderer_get_width fried_software_renderer_get_width
#define fried_renderer_has_vsync fried_software_renderer_has_vsync
#define fried_renderer_present fried_software_renderer_present
#define fried_renderer_set_draw_color fried_software_renderer_set_draw_color
#define fried_renderer_touch_to_logical fried_software_renderer_touch_to_logical
#define fried_renderer_window_to_logical fried_software_renderer_window_to_logical

#define fried_texture_create_blank fried_software_texture_create_blank
#define fried_texture_destroy fried_software_texture_destroy
#define fried_texture_get_downscale fried_software_texture_get_downscale
#define fried_texture_get_height fried_software_texture_get_height
#define fried_texture_get_width fried_software_texture_get_width
#define fried_texture_load fried_software_texture_load
#define fried_texture_write_alpha fried_software_texture_write_alpha

// The fonts know renderers by their public ids, which renderer_nds.cpp gives
// them on the software renderer's behalf.
#define fried_font_release_renderer fried_software_font_release_renderer
