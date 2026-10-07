package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;

class Text extends Component {
	public var font(default, set):Font;
	public var text(default, set):String;
	public var color:Color;

	public var width(get, never):Int;
	public var height(get, never):Int;

	var measuredWidth:Int;
	var isMeasured:Bool;

	public function new(font:Font, text:String, color:Color) {
		super();
		this.font = font;
		this.text = text;
		this.color = color;
	}

	override function draw():Void {
		if (font == null || text == null || text == "") {
			return;
		}
		DrawQueue.submitText(gameObject.priority, font, text, transform.x, transform.y, width * transform.scaleX, height * transform.scaleY, color,
			transform.rotation);
	}

	function set_font(value:Font):Font {
		if (value != font) {
			font = value;
			isMeasured = false;
		}
		return font;
	}

	function set_text(value:String):String {
		if (value != text) {
			text = value;
			isMeasured = false;
		}
		return text;
	}

	function get_width():Int {
		if (font == null || text == null) {
			return 0;
		}
		if (!isMeasured) {
			measuredWidth = font.measureWidth(text);
			isMeasured = true;
		}
		return measuredWidth;
	}

	function get_height():Int {
		return font == null ? 0 : font.lineHeight;
	}
}
