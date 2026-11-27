package fried.ui.css;

import fried.ui.SourceLines;
import fried.ui.UIDiagnostics;

// The rules and font faces a sheet's text holds.
class ParsedSheet {
	public var rules:Array<StyleRule> = [];

	// Family to the path its @font-face gives, as written.
	public var fontFaces:Map<String, String> = new Map();

	public function new() {}
}

// Reads the subset of CSS the engine draws: rules with simple selectors and @font-face. What it leaves out is reported with its line and column and skipped, the rest of the file still applies.
class CssParser {
	var path:String;
	var text:String;
	var lines:SourceLines;
	var result:ParsedSheet;

	public static function parse(path:String, text:String):ParsedSheet {
		return new CssParser(path, text).run();
	}

	function new(path:String, text:String) {
		this.path = path;
		this.text = text;
		lines = new SourceLines(text);
		result = new ParsedSheet();
	}

	function run():ParsedSheet {
		var index = 0;
		while (true) {
			index = skipSpace(index);
			if (index >= text.length) {
				break;
			}
			if (text.charAt(index) == "@") {
				index = atRule(index);
			} else {
				index = rule(index);
			}
		}
		return result;
	}

	function atRule(start:Int):Int {
		var nameEnd = start + 1;
		while (nameEnd < text.length && isNameCharacter(text.charCodeAt(nameEnd))) {
			nameEnd++;
		}
		var name = text.substring(start + 1, nameEnd).toLowerCase();
		var stop = findAny(nameEnd, "{;");
		if (stop < 0) {
			problem(start, 'the rule "@$name" is never closed', "close it with a }");
			return text.length;
		}
		if (text.charAt(stop) == ";") {
			problem(start, 'the rule "@$name" is not supported', "remove it");
			return stop + 1;
		}
		var end = blockEnd(stop);
		if (name == "font-face") {
			fontFace(stop + 1, end);
		} else {
			problem(start, 'the rule "@$name" is not supported', name == "media" ? "write the styles for the screen you target in the sheet that screen uses" : "remove it");
		}
		return end + 1;
	}

	function fontFace(from:Int, to:Int):Void {
		var family:Null<String> = null;
		var source:Null<String> = null;
		for (declaration in declarationRanges(from, to)) {
			var parts = splitDeclaration(declaration.start, declaration.end);
			if (parts == null) {
				continue;
			}
			if (parts.name == "font-family") {
				family = unquote(parts.value);
			} else if (parts.name == "src") {
				var open = parts.value.indexOf("url(");
				var close = parts.value.indexOf(")", open);
				if (open >= 0 && close > open) {
					source = unquote(parts.value.substring(open + 4, close));
				}
			}
		}
		if (family == null || source == null) {
			problem(from, "an @font-face needs a font-family and a src: url()", 'write font-family: "Name"; src: url("file.ttf");');
			return;
		}
		result.fontFaces.set(family, source);
	}

	function rule(start:Int):Int {
		var open = findAny(start, "{");
		if (open < 0) {
			problem(start, "a rule is never opened", "write its declarations between { and }");
			return text.length;
		}
		var end = blockEnd(open);
		var prelude = text.substring(start, open);
		var selectors:Array<Selector> = [];
		var isUsable = true;
		for (piece in prelude.split(",")) {
			var selector = Selector.parse(StringTools.trim(removeComments(piece)), message -> problem(start, 'the selector "${StringTools.trim(prelude)}": $message', "write a tag, .class, #id or :hover, :active, :focus, :disabled, joined by spaces or >"));
			if (selector == null) {
				isUsable = false;
			} else {
				selectors.push(selector);
			}
		}
		if (isUsable) {
			var declarations = [];
			for (range in declarationRanges(open + 1, end)) {
				var parts = splitDeclaration(range.start, range.end);
				if (parts != null) {
					for (declaration in CssProperties.parse(parts.name, parts.value, (message, fix) -> problem(range.start, message, fix))) {
						declarations.push(declaration);
					}
				}
			}
			for (selector in selectors) {
				result.rules.push(new StyleRule(selector, declarations, result.rules.length));
			}
		}
		return end + 1;
	}

	// The spans of the declarations of a block, split by the semicolons outside parentheses, quotes and nested braces.
	function declarationRanges(from:Int, to:Int):Array<{start:Int, end:Int}> {
		var ranges = [];
		var depth = 0;
		var quote = 0;
		var start = from;
		var index = from;
		while (index < to) {
			var code = text.charCodeAt(index);
			if (quote != 0) {
				if (code == quote) {
					quote = 0;
				}
			} else if (code == 34 || code == 39) {
				quote = code;
			} else if (code == 47 && text.charCodeAt(index + 1) == 42) {
				index = skipComment(index) - 1;
			} else if (code == 40 || code == 123) {
				depth++;
			} else if (code == 41 || code == 125) {
				depth--;
			} else if (code == 59 && depth == 0) {
				ranges.push({start: start, end: index});
				start = index + 1;
			}
			index++;
		}
		ranges.push({start: start, end: to});
		return ranges.filter(range -> StringTools.trim(removeComments(text.substring(range.start, range.end))) != "");
	}

	function splitDeclaration(start:Int, end:Int):Null<{name:String, value:String}> {
		var body = removeComments(text.substring(start, end));
		var first = start + leadingSpace(text, start);
		if (body.indexOf("{") >= 0) {
			problem(first, "a nested rule is not supported", "write it as its own rule with the full selector");
			return null;
		}
		var colon = body.indexOf(":");
		if (colon < 0) {
			problem(first, '"${StringTools.trim(body)}" is not a declaration', "write property: value;");
			return null;
		}
		var name = StringTools.trim(body.substr(0, colon)).toLowerCase();
		var value = StringTools.trim(body.substr(colon + 1));
		var important = value.toLowerCase().indexOf("!important");
		if (important >= 0) {
			problem(first, "!important is not supported, so the rule that comes last wins", "remove it and raise the specificity of the selector instead");
			value = StringTools.trim(value.substr(0, important));
		}
		return {name: name, value: value};
	}

	function problem(index:Int, message:String, fix:String):Void {
		UIDiagnostics.report(path, lines.line(index), lines.column(index), message, fix);
	}

	// Where the block opened at `open` closes, or the end of the text.
	function blockEnd(open:Int):Int {
		var depth = 0;
		var quote = 0;
		var index = open;
		while (index < text.length) {
			var code = text.charCodeAt(index);
			if (quote != 0) {
				if (code == quote) {
					quote = 0;
				}
			} else if (code == 34 || code == 39) {
				quote = code;
			} else if (code == 47 && text.charCodeAt(index + 1) == 42) {
				index = skipComment(index) - 1;
			} else if (code == 123) {
				depth++;
			} else if (code == 125) {
				depth--;
				if (depth == 0) {
					return index;
				}
			}
			index++;
		}
		problem(open, "a block is never closed", "close it with a }");
		return text.length;
	}

	function findAny(from:Int, characters:String):Int {
		var index = from;
		while (index < text.length) {
			if (text.charCodeAt(index) == 47 && text.charCodeAt(index + 1) == 42) {
				index = skipComment(index);
				continue;
			}
			if (characters.indexOf(text.charAt(index)) >= 0) {
				return index;
			}
			index++;
		}
		return -1;
	}

	function skipSpace(from:Int):Int {
		var index = from;
		while (index < text.length) {
			var code = text.charCodeAt(index);
			if (code == 47 && text.charCodeAt(index + 1) == 42) {
				index = skipComment(index);
			} else if (code == 32 || code == 9 || code == 10 || code == 13) {
				index++;
			} else {
				break;
			}
		}
		return index;
	}

	function skipComment(start:Int):Int {
		var end = text.indexOf("*/", start + 2);
		return end < 0 ? text.length : end + 2;
	}

	static function leadingSpace(text:String, from:Int):Int {
		var index = from;
		while (index < text.length && (text.charCodeAt(index) == 32 || text.charCodeAt(index) == 9 || text.charCodeAt(index) == 10 || text.charCodeAt(index) == 13)) {
			index++;
		}
		return index - from;
	}

	static function removeComments(value:String):String {
		var result = value;
		var start = result.indexOf("/*");
		while (start >= 0) {
			var end = result.indexOf("*/", start + 2);
			result = result.substr(0, start) + (end < 0 ? "" : result.substr(end + 2));
			start = result.indexOf("/*");
		}
		return result;
	}

	static function unquote(value:String):String {
		var trimmed = StringTools.trim(value);
		if (trimmed.length >= 2 && (trimmed.charAt(0) == '"' || trimmed.charAt(0) == "'")) {
			return trimmed.substr(1, trimmed.length - 2);
		}
		return trimmed;
	}

	static function isNameCharacter(code:Null<Int>):Bool {
		return code != null && (code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 97 && code <= 122 || code == 45 || code == 95);
	}
}
