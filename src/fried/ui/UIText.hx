package fried.ui;

import fried.graphics.Font;
import fried.graphics.TextLayout;

// A run of text inside an element. It takes the style of its parent and is drawn in lines the layout breaks.
@:allow(fried.ui)
class UIText extends UIElement {
	public var text(default, set):String;

	var lines:Array<String>;
	var lineWidths:Array<Int>;

	// What measuring costs is kept for as long as the text and the font stay the same: the lines it has when nothing wraps, the widest of them, and the lines for the last width it was broken to.
	var measuredText:Null<String>;
	var measuredFont:Null<Font>;
	var naturalLines:Array<String>;
	var naturalWidths:Array<Int>;
	var naturalWidth:Int;
	var wrappedTo:Int;
	var wrappedLines:Array<String>;
	var wrappedWidths:Array<Int>;

	// For a text with {{names}} in it: the pieces between them, and the names, where the nth name goes after the nth piece.
	var pieces:Null<Array<String>>;
	var names:Null<Array<String>>;

	public function new(text:String) {
		super("#text");
		kind = UIElement.TEXT;
		this.text = text;
		lines = [];
		lineWidths = [];
		naturalLines = [];
		naturalWidths = [];
		naturalWidth = 0;
		wrappedTo = -1;
	}

	// The width of the widest line when nothing wraps.
	function widest(font:Font):Int {
		measure(font);
		return naturalWidth;
	}

	// Breaks the text into the lines that fit a width, which are the lines of the text itself when it already fits.
	function fit(font:Font, width:Int):Void {
		measure(font);
		if (naturalWidth <= width) {
			lines = naturalLines;
			lineWidths = naturalWidths;
			return;
		}
		if (wrappedTo != width) {
			wrappedLines = TextLayout.breakLines(font, text, width);
			wrappedWidths = [for (line in wrappedLines) font.measureWidth(line)];
			wrappedTo = width;
		}
		lines = wrappedLines;
		lineWidths = wrappedWidths;
	}

	function measure(font:Font):Void {
		if (font == measuredFont && text == measuredText) {
			return;
		}
		measuredFont = font;
		measuredText = text;
		naturalLines = text.split("\n");
		naturalWidths = [for (line in naturalLines) font.measureWidth(line)];
		naturalWidth = 0;
		for (width in naturalWidths) {
			naturalWidth = width > naturalWidth ? width : naturalWidth;
		}
		wrappedTo = -1;
	}

	override function get_textContent():String {
		return text;
	}

	override function set_textContent(value:String):String {
		text = value;
		return value;
	}

	// Makes the text a template, which `refresh` fills from the values of the names. Returns the names it holds, or an empty list for a text that has none.
	function bindTemplate(template:String):Array<String> {
		var found = [];
		var literal = [];
		var pieceStart = 0;
		var from = 0;
		while (true) {
			var open = template.indexOf("{{", from);
			var close = open < 0 ? -1 : template.indexOf("}}", open + 2);
			if (close < 0) {
				break;
			}
			var name = StringTools.trim(template.substring(open + 2, close));
			if (!isName(name)) {
				from = open + 2;
				continue;
			}
			literal.push(template.substring(pieceStart, open));
			found.push(name);
			from = close + 2;
			pieceStart = from;
		}
		if (found.length == 0) {
			return found;
		}
		literal.push(template.substr(pieceStart));
		pieces = literal;
		names = found;
		return found;
	}

	static function isName(name:String):Bool {
		if (name == "") {
			return false;
		}
		for (index in 0...name.length) {
			var code = name.charCodeAt(index);
			var isLetter = code >= 65 && code <= 90 || code >= 97 && code <= 122 || code == 95;
			if (!isLetter && !(index > 0 && code >= 48 && code <= 57)) {
				return false;
			}
		}
		return true;
	}

	// The words of a text, each blank run being one space, as a browser shows text.
	static function collapse(text:String):String {
		var result = new StringBuf();
		var isPending = false;
		var hasWord = false;
		for (index in 0...text.length) {
			var code = text.charCodeAt(index);
			if (code == 32 || code == 9 || code == 10 || code == 13) {
				isPending = hasWord;
			} else {
				if (isPending) {
					result.addChar(32);
					isPending = false;
				}
				result.addChar(code);
				hasWord = true;
			}
		}
		return result.toString();
	}

	function refresh(values:Map<String, String>):Void {
		if (pieces == null || names == null) {
			return;
		}
		var result = pieces[0];
		for (index in 0...names.length) {
			var value = values.get(names[index]);
			result += (value == null ? "" : value) + pieces[index + 1];
		}
		text = result;
	}

	function set_text(value:String):String {
		if (value != text) {
			text = value;
			if (document != null) {
				document.invalidateLayout();
			}
		}
		return text;
	}
}
