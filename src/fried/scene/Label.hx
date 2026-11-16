package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;

// Text on the screen, in one color, which sizes its control.
@:serializable
class Label extends Control {
	public var font(default, set):Font;
	public var text(default, set):String;
	public var color:Color;

	// The width, before the scale, at which a line is broken between words into the next one. Zero leaves the text on one line, and a word wider than this still gets a line of its own. A broken text is not meant to be rotated.
	public var maxWidth(default, set):Int;

	@:noSerialize public var textWidth(get, never):Int;
	@:noSerialize public var textHeight(get, never):Int;

	var measuredWidth:Int;
	var lines:Array<String>;
	var lineWidths:Array<Int>;
	var isMeasured:Bool;

	public function new(font:Font = null, text:String = "", color:Color = null) {
		super("Label");
		this.font = font;
		this.text = text;
		this.color = color != null ? color : Color.rgb(255, 255, 255);
		maxWidth = 0;
		lines = [];
		lineWidths = [];
	}

	override function draw():Void {
		if (font == null || text == null || text == "") {
			return;
		}
		measure();
		var lineHeight = font.lineHeight * worldScaleY;
		var scaleX = worldScaleX;
		for (index in 0...lines.length) {
			if (lines[index] == "") {
				continue;
			}
			DrawQueue.submitText(priority, font, lines[index], worldX, worldY + index * lineHeight, lineWidths[index] * scaleX, lineHeight, color,
				worldRotation);
		}
	}

	override function intrinsicWidth():Float {
		return font == null ? -1 : textWidth;
	}

	override function intrinsicHeight():Float {
		return font == null ? -1 : textHeight;
	}

	function changed():Void {
		isMeasured = false;
		markWorldDirty();
	}

	function set_font(value:Font):Font {
		if (value != font) {
			font = value;
			changed();
		}
		return font;
	}

	function set_maxWidth(value:Int):Int {
		if (value != maxWidth) {
			maxWidth = value;
			changed();
		}
		return maxWidth;
	}

	function set_text(value:String):String {
		if (value != text) {
			text = value;
			changed();
		}
		return text;
	}

	function get_textWidth():Int {
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

	function get_textHeight():Int {
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
