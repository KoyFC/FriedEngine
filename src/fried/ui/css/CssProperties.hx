package fried.ui.css;

import fried.graphics.Color;
import fried.ui.css.StyleValue;

private enum PropertyKind {
	Length(allowPercent:Bool, allowAuto:Bool);
	Keywords(allowed:Array<String>);
	ColorKind;
	NumberKind;
	FamilyKind;
}

private class Property {
	public var id:Int;
	public var kind:PropertyKind;

	public function new(id:Int, kind:PropertyKind) {
		this.id = id;
		this.kind = kind;
	}
}

// The properties the subset knows, how each value is read, and the shorthands that spread into them.
class CssProperties {
	public static inline var DISPLAY:Int = 0;
	public static inline var FLEX_DIRECTION:Int = 1;
	public static inline var JUSTIFY_CONTENT:Int = 2;
	public static inline var ALIGN_ITEMS:Int = 3;
	public static inline var GAP:Int = 4;
	public static inline var FLEX_GROW:Int = 5;
	public static inline var WIDTH:Int = 6;
	public static inline var HEIGHT:Int = 7;
	public static inline var MIN_WIDTH:Int = 8;
	public static inline var MIN_HEIGHT:Int = 9;
	public static inline var MAX_WIDTH:Int = 10;
	public static inline var MAX_HEIGHT:Int = 11;
	public static inline var MARGIN_TOP:Int = 12;
	public static inline var MARGIN_RIGHT:Int = 13;
	public static inline var MARGIN_BOTTOM:Int = 14;
	public static inline var MARGIN_LEFT:Int = 15;
	public static inline var PADDING_TOP:Int = 16;
	public static inline var PADDING_RIGHT:Int = 17;
	public static inline var PADDING_BOTTOM:Int = 18;
	public static inline var PADDING_LEFT:Int = 19;
	public static inline var BORDER_TOP_WIDTH:Int = 20;
	public static inline var BORDER_RIGHT_WIDTH:Int = 21;
	public static inline var BORDER_BOTTOM_WIDTH:Int = 22;
	public static inline var BORDER_LEFT_WIDTH:Int = 23;
	public static inline var BORDER_COLOR:Int = 24;
	public static inline var BORDER_STYLE:Int = 25;
	public static inline var BACKGROUND_COLOR:Int = 26;
	public static inline var COLOR:Int = 27;
	public static inline var FONT_FAMILY:Int = 28;
	public static inline var FONT_SIZE:Int = 29;
	public static inline var TEXT_ALIGN:Int = 30;
	public static inline var VISIBILITY:Int = 31;
	public static inline var OPACITY:Int = 32;
	public static inline var COUNT:Int = 33;

	// The size an em and a rem are worth, since the subset has no root font size to follow.
	static inline var EM:Float = 16.0;

	// The width of a border written without one, what a browser calls medium.
	static inline var MEDIUM_BORDER:Float = 3.0;

	static var properties:Map<String, Property> = build();
	static var inheritedIds:Array<Bool> = [for (id in 0...COUNT) id == COLOR || id == FONT_FAMILY || id == FONT_SIZE || id == TEXT_ALIGN || id == VISIBILITY];

	public static function isInherited(property:Int):Bool {
		return inheritedIds[property];
	}

	static function build():Map<String, Property> {
		var map = new Map<String, Property>();
		function add(name:String, id:Int, kind:PropertyKind):Void {
			map.set(name, new Property(id, kind));
		}
		add("display", DISPLAY, Keywords(["block", "flex", "none"]));
		add("flex-direction", FLEX_DIRECTION, Keywords(["row", "column"]));
		add("justify-content", JUSTIFY_CONTENT, Keywords(["flex-start", "center", "flex-end", "space-between"]));
		add("align-items", ALIGN_ITEMS, Keywords(["stretch", "flex-start", "center", "flex-end"]));
		add("gap", GAP, Length(false, false));
		add("flex-grow", FLEX_GROW, NumberKind);
		add("width", WIDTH, Length(true, true));
		add("height", HEIGHT, Length(true, true));
		add("min-width", MIN_WIDTH, Length(true, true));
		add("min-height", MIN_HEIGHT, Length(true, true));
		add("max-width", MAX_WIDTH, Length(true, true));
		add("max-height", MAX_HEIGHT, Length(true, true));
		add("margin-top", MARGIN_TOP, Length(false, false));
		add("margin-right", MARGIN_RIGHT, Length(false, false));
		add("margin-bottom", MARGIN_BOTTOM, Length(false, false));
		add("margin-left", MARGIN_LEFT, Length(false, false));
		add("padding-top", PADDING_TOP, Length(false, false));
		add("padding-right", PADDING_RIGHT, Length(false, false));
		add("padding-bottom", PADDING_BOTTOM, Length(false, false));
		add("padding-left", PADDING_LEFT, Length(false, false));
		add("border-top-width", BORDER_TOP_WIDTH, Length(false, false));
		add("border-right-width", BORDER_RIGHT_WIDTH, Length(false, false));
		add("border-bottom-width", BORDER_BOTTOM_WIDTH, Length(false, false));
		add("border-left-width", BORDER_LEFT_WIDTH, Length(false, false));
		add("border-color", BORDER_COLOR, ColorKind);
		add("border-style", BORDER_STYLE, Keywords(["solid", "none"]));
		add("background-color", BACKGROUND_COLOR, ColorKind);
		add("color", COLOR, ColorKind);
		add("font-family", FONT_FAMILY, FamilyKind);
		add("font-size", FONT_SIZE, Length(false, false));
		add("text-align", TEXT_ALIGN, Keywords(["left", "center", "right"]));
		add("visibility", VISIBILITY, Keywords(["visible", "hidden"]));
		add("opacity", OPACITY, NumberKind);
		return map;
	}

	// The declarations a name and a value stand for, empty when the declaration is left out. `report` is told what was wrong and how to fix it.
	public static function parse(name:String, value:String, report:(message:String, fix:String) -> Void):Array<Declaration> {
		switch (name) {
			case "margin":
				return spreadBox(name, value, [MARGIN_TOP, MARGIN_RIGHT, MARGIN_BOTTOM, MARGIN_LEFT], report);
			case "padding":
				return spreadBox(name, value, [PADDING_TOP, PADDING_RIGHT, PADDING_BOTTOM, PADDING_LEFT], report);
			case "border-width":
				return spreadBox(name, value, [BORDER_TOP_WIDTH, BORDER_RIGHT_WIDTH, BORDER_BOTTOM_WIDTH, BORDER_LEFT_WIDTH], report);
			case "border":
				return parseBorder(value, report);
			case "flex":
				return parse("flex-grow", value, report);
			case _:
		}
		var property = properties.get(name);
		if (property == null) {
			report('the property "$name" is not supported', "remove it, or see the list of supported properties in the docs");
			return [];
		}
		var parsed = parseValue(name, property.kind, value, report);
		return parsed == null ? [] : [new Declaration(property.id, parsed)];
	}

	static function spreadBox(name:String, value:String, ids:Array<Int>, report:(message:String, fix:String) -> Void):Array<Declaration> {
		var words = splitWords(value);
		if (words.length < 1 || words.length > 4) {
			report('"$name: $value" needs one to four values', "write one, two, three or four lengths");
			return [];
		}
		var lengths:Array<StyleValue> = [];
		for (word in words) {
			var parsed = parseValue(name, Length(false, false), word, report);
			if (parsed == null) {
				return [];
			}
			lengths.push(parsed);
		}
		// One value is every side, two are vertical then horizontal, three are top, horizontal, bottom, and four go around from the top.
		var top = lengths[0];
		var right = lengths.length > 1 ? lengths[1] : top;
		var bottom = lengths.length > 2 ? lengths[2] : top;
		var left = lengths.length > 3 ? lengths[3] : right;
		return [new Declaration(ids[0], top), new Declaration(ids[1], right), new Declaration(ids[2], bottom), new Declaration(ids[3], left)];
	}

	static function parseBorder(value:String, report:(message:String, fix:String) -> Void):Array<Declaration> {
		var width:StyleValue = Px(MEDIUM_BORDER);
		var style:StyleValue = Keyword("solid");
		var color:Null<StyleValue> = null;
		for (word in splitWords(value)) {
			if (word == "solid" || word == "none") {
				style = Keyword(word);
			} else if (isLengthWord(word)) {
				var parsed = parseValue("border", Length(false, false), word, report);
				if (parsed == null) {
					return [];
				}
				width = parsed;
			} else {
				var parsed = parseValue("border", ColorKind, word, report);
				if (parsed == null) {
					return [];
				}
				color = parsed;
			}
		}
		var declarations = [for (id in [BORDER_TOP_WIDTH, BORDER_RIGHT_WIDTH, BORDER_BOTTOM_WIDTH, BORDER_LEFT_WIDTH]) new Declaration(id, width)];
		declarations.push(new Declaration(BORDER_STYLE, style));
		if (color != null) {
			declarations.push(new Declaration(BORDER_COLOR, color));
		}
		return declarations;
	}

	static function isLengthWord(word:String):Bool {
		var first = word.charCodeAt(0);
		return first != null && (first >= 48 && first <= 57 || first == 45 || first == 46);
	}

	static function parseValue(name:String, kind:PropertyKind, value:String, report:(message:String, fix:String) -> Void):Null<StyleValue> {
		switch (kind) {
			case Keywords(allowed):
				var word = value.toLowerCase();
				if (allowed.indexOf(word) >= 0) {
					return Keyword(word);
				}
				report('"$value" is not a value of $name', "use one of " + allowed.join(", "));
				return null;
			case ColorKind:
				var color = parseColor(value);
				if (color == null) {
					report('"$value" is not a color the subset reads', "write #rgb, #rrggbb, #rrggbbaa, rgb(), rgba() or one of white, black, red, green, blue, gray and transparent");
					return null;
				}
				return ColorValue(color);
			case NumberKind:
				var number = Std.parseFloat(value);
				if (Math.isNaN(number) || number < 0) {
					report('"$value" is not a number for $name', "write a number of zero or more");
					return null;
				}
				return Number(number);
			case FamilyKind:
				var names = [];
				for (part in value.split(",")) {
					var family = StringTools.trim(part);
					if (family.length >= 2 && (family.charAt(0) == '"' || family.charAt(0) == "'")) {
						family = family.substr(1, family.length - 2);
					}
					if (family != "") {
						names.push(family);
					}
				}
				if (names.length == 0) {
					report("font-family has no family", "name a family from an @font-face");
					return null;
				}
				return Family(names);
			case Length(allowPercent, allowAuto):
				return parseLength(name, value.toLowerCase(), allowPercent, allowAuto, report);
		}
	}

	static function parseLength(name:String, word:String, allowPercent:Bool, allowAuto:Bool, report:(message:String, fix:String) -> Void):Null<StyleValue> {
		if (word == "auto" || word == "none" && StringTools.startsWith(name, "max-")) {
			if (allowAuto) {
				return Auto;
			}
			report('"auto" is not a value of $name', name.indexOf("margin") == 0 ? "center with justify-content and align-items on the parent" : "write a length in px");
			return null;
		}
		var number = Std.parseFloat(word);
		if (Math.isNaN(number)) {
			report('"$word" is not a length for $name', "write a length in px");
			return null;
		}
		var unit = word.substr(numberLength(word));
		switch (unit) {
			case "px":
				return Px(number);
			case "":
				if (number == 0) {
					return Px(0);
				}
			case "%":
				if (allowPercent) {
					return Percent(number);
				}
				report('a percentage is not a value of $name', "write a length in px");
				return null;
			case "rem" | "em":
				report('"$word" is read as ${number * EM}px, since the subset has no root font size', 'write ${number * EM}px');
				return Px(number * EM);
			case _:
		}
		report('"$word" is not a length in a unit the subset reads', "write a length in px");
		return null;
	}

	// How many characters at the start of the word are the number.
	static function numberLength(word:String):Int {
		var index = 0;
		while (index < word.length) {
			var code = word.charCodeAt(index);
			if (code >= 48 && code <= 57 || code == 46 || code == 45 || code == 43) {
				index++;
			} else {
				break;
			}
		}
		return index;
	}

	// The words of a value, split by spaces that are not inside parentheses.
	public static function splitWords(value:String):Array<String> {
		var words = [];
		var depth = 0;
		var current = new StringBuf();
		var hasCurrent = false;
		for (index in 0...value.length) {
			var character = value.charAt(index);
			if (character == "(") {
				depth++;
			} else if (character == ")") {
				depth--;
			}
			if ((character == " " || character == "\t" || character == "\n" || character == "\r") && depth == 0) {
				if (hasCurrent) {
					words.push(current.toString());
					current = new StringBuf();
					hasCurrent = false;
				}
			} else {
				current.add(character);
				hasCurrent = true;
			}
		}
		if (hasCurrent) {
			words.push(current.toString());
		}
		return words;
	}

	public static function parseColor(value:String):Null<Color> {
		var text = StringTools.trim(value).toLowerCase();
		if (StringTools.startsWith(text, "#")) {
			return parseHexColor(text.substr(1));
		}
		if (StringTools.startsWith(text, "rgba(") || StringTools.startsWith(text, "rgb(")) {
			return parseFunctionColor(text);
		}
		return switch (text) {
			case "white": Color.rgb(255, 255, 255);
			case "black": Color.rgb(0, 0, 0);
			case "red": Color.rgb(255, 0, 0);
			case "green": Color.rgb(0, 128, 0);
			case "blue": Color.rgb(0, 0, 255);
			case "gray" | "grey": Color.rgb(128, 128, 128);
			case "transparent": Color.rgba(0, 0, 0, 0);
			case _: null;
		}
	}

	static function parseHexColor(digits:String):Null<Color> {
		var length = digits.length;
		if (length != 3 && length != 6 && length != 8) {
			return null;
		}
		var values = [];
		if (length == 3) {
			for (index in 0...3) {
				var digit = Std.parseInt("0x" + digits.charAt(index));
				if (digit == null) {
					return null;
				}
				values.push(digit * 17);
			}
		} else {
			for (index in 0...length >> 1) {
				var pair = Std.parseInt("0x" + digits.substr(index * 2, 2));
				if (pair == null) {
					return null;
				}
				values.push(pair);
			}
		}
		return Color.rgba(values[0], values[1], values[2], values.length > 3 ? values[3] : 255);
	}

	static function parseFunctionColor(text:String):Null<Color> {
		var open = text.indexOf("(");
		var close = text.lastIndexOf(")");
		if (close < open) {
			return null;
		}
		var arguments = splitWords(StringTools.replace(StringTools.replace(text.substring(open + 1, close), ",", " "), "/", " "));
		if (arguments.length != 3 && arguments.length != 4) {
			return null;
		}
		var channels = [];
		for (index in 0...3) {
			var channel = Std.parseFloat(arguments[index]);
			if (Math.isNaN(channel)) {
				return null;
			}
			channels.push(Std.int(Math.max(0, Math.min(255, channel))));
		}
		var alpha = 255;
		if (arguments.length == 4) {
			var fraction = Std.parseFloat(arguments[3]);
			if (Math.isNaN(fraction)) {
				return null;
			}
			alpha = Std.int(Math.max(0, Math.min(1, fraction)) * 255 + 0.5);
		}
		return Color.rgba(channels[0], channels[1], channels[2], alpha);
	}
}
