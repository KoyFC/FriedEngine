package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;

@:serializable
class Text extends Component {
	public var font(default, set):Font;
	public var text(default, set):String;
	public var color:Color;

	// The width, before the scale, at which a line is broken between words into the next one. Zero leaves the text on one line, and a word wider than this still gets a line of its own. A broken text is not meant to be rotated.
	public var maxWidth(default, set):Int;

	public var width(get, never):Int;
	public var height(get, never):Int;

	var measuredWidth:Int;
	var lines:Array<String>;
	var lineWidths:Array<Int>;
	var isMeasured:Bool;

	public function new(font:Font, text:String, color:Color) {
		super();
		this.font = font;
		this.text = text;
		this.color = color;
		maxWidth = 0;
		lines = [];
		lineWidths = [];
	}

	override function draw():Void {
		if (font == null || text == null || text == "") {
			return;
		}
		measure();
		var lineHeight = font.lineHeight * transform.scaleY;
		for (index in 0...lines.length) {
			if (lines[index] == "") {
				continue;
			}
			DrawQueue.submitText(gameObject.priority, font, lines[index], transform.x, transform.y + index * lineHeight, lineWidths[index] * transform.scaleX,
				lineHeight, color, transform.rotation);
		}
	}

	override function intrinsicWidth():Float {
		return font == null ? -1 : width;
	}

	override function intrinsicHeight():Float {
		return font == null ? -1 : height;
	}

	function set_font(value:Font):Font {
		if (value != font) {
			font = value;
			isMeasured = false;
		}
		return font;
	}

	function set_maxWidth(value:Int):Int {
		if (value != maxWidth) {
			maxWidth = value;
			isMeasured = false;
		}
		return maxWidth;
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
		measure();
		return measuredWidth;
	}

	// Breaks the text into lines and measures the widest, once for as long as the font, the text and the width stay the same.
	function measure():Void {
		if (isMeasured) {
			return;
		}
		lines = maxWidth > 0 ? breakLines() : [text];
		measuredWidth = 0;
		lineWidths = [];
		for (line in lines) {
			var lineWidth = font.measureWidth(line);
			lineWidths.push(lineWidth);
			measuredWidth = lineWidth > measuredWidth ? lineWidth : measuredWidth;
		}
		isMeasured = true;
	}

	function breakLines():Array<String> {
		var result = [];
		for (paragraph in text.split("\n")) {
			var line:Null<String> = null;
			for (word in paragraph.split(" ")) {
				if (line == null) {
					line = word;
				} else if (font.measureWidth(line + " " + word) <= maxWidth) {
					line += " " + word;
				} else {
					result.push(line);
					line = word;
				}
			}
			result.push(line == null ? "" : line);
		}
		return result;
	}

	function get_height():Int {
		if (font == null) {
			return 0;
		}
		if (text == null) {
			return font.lineHeight;
		}
		measure();
		return font.lineHeight * lines.length;
	}
}
