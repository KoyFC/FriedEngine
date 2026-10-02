package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.graphics.Texture;

class Text extends Component {
	public var font(default, set):Font;
	public var text(default, set):String;
	public var color(default, set):Color;

	public var width(get, never):Int;
	public var height(get, never):Int;

	var texture:Texture;
	var renderer:Renderer;
	var isDirty:Bool;

	public function new(font:Font, text:String, color:Color) {
		super();
		this.font = font;
		this.text = text;
		this.color = color;
		isDirty = true;
	}

	override function draw():Void {
		var target = DrawQueue.currentRenderTarget;
		if (target == null) {
			return;
		}
		if (isDirty || renderer != target) {
			render(target);
		}
		if (texture == null) {
			return;
		}
		DrawQueue.submitTexture(gameObject.priority, texture, Std.int(transform.x), Std.int(transform.y), Std.int(texture.width * transform.scaleX),
			Std.int(texture.height * transform.scaleY), transform.rotation);
	}

	override function destroy():Void {
		discard();
	}

	// A string is a texture, so the render happens once per change rather than
	// once per frame, and only where a render target is known to be current.
	function render(target:Renderer):Void {
		discard();
		isDirty = false;
		renderer = target;
		if (font == null || text == null || text == "") {
			return;
		}
		texture = font.renderText(target, text, color);
	}

	function discard():Void {
		if (texture != null) {
			texture.destroy();
			texture = null;
		}
		renderer = null;
	}

	function set_font(value:Font):Font {
		if (value != font) {
			font = value;
			isDirty = true;
		}
		return font;
	}

	function set_text(value:String):String {
		if (value != text) {
			text = value;
			isDirty = true;
		}
		return text;
	}

	function set_color(value:Color):Color {
		if (value != color) {
			color = value;
			isDirty = true;
		}
		return color;
	}

	// Measured from the font rather than from the texture, so a size is there
	// before the first draw has rendered anything and after a change that has
	// not been rendered yet.
	function get_width():Int {
		if (font == null || text == null) {
			return 0;
		}
		return font.measureWidth(text);
	}

	function get_height():Int {
		return font == null ? 0 : font.lineHeight;
	}
}
