package fried.io;

private class Failure {
	public var at:Int;
	public var message:String;

	public function new(at:Int, message:String) {
		this.at = at;
		this.message = message;
	}
}

// Reads the Fried YAML subset (see docs/reference/yaml.md), which is a superset of JSON and gives what `haxe.Json.parse` gives: anonymous objects, arrays, Int, Float, Bool, String and null. Nothing here touches the platform, so a build macro can use it.
class Yaml {
	public static function parse(text:String, fileName:String):Dynamic {
		var parser = new YamlParser(text);
		try {
			return parser.document();
		} catch (failure:Failure) {
			throw '$fileName:${parser.where(failure.at)}: ${failure.message}';
		}
	}
}

private class YamlParser {
	var text:String;
	var at:Int = 0;

	public function new(text:String) {
		this.text = text;
	}

	public function document():Dynamic {
		if (StringTools.startsWith(text, "\u{FEFF}")) {
			at = 1;
		}
		if (!nextContent(false)) {
			return null;
		}
		if (peek() == "%") {
			fail(at, "Fried YAML does not support directives");
		}
		if (isDocumentMarker("---")) {
			at += 3;
			if (!nextContent(false)) {
				return null;
			}
		}
		var root = node();
		if (nextContent(false)) {
			if (isDocumentMarker("---") || isDocumentMarker("...")) {
				fail(at, "Fried YAML does not support several documents in a file");
			}
			fail(at, "this text is not part of the value, which may be a wrong indentation");
		}
		return root;
	}

	public function where(position:Int):String {
		var line = 1;
		var start = 0;
		for (i in 0...position) {
			if (text.charCodeAt(i) == 10) {
				line++;
				start = i + 1;
			}
		}
		return '$line:${position - start + 1}';
	}

	function fail(position:Int, message:String):Dynamic {
		throw new Failure(position, message);
	}

	function atEnd():Bool {
		return at >= text.length;
	}

	function peek(offset:Int = 0):String {
		return at + offset < text.length ? text.charAt(at + offset) : "";
	}

	static function isBlank(c:String):Bool {
		return c == " " || c == "\t";
	}

	static function isDigit(c:String):Bool {
		return c >= "0" && c <= "9" && c.length == 1;
	}

	function blankOrEnd(position:Int):Bool {
		if (position >= text.length) {
			return true;
		}
		var c = text.charAt(position);
		return c == " " || c == "\t" || c == "\n" || c == "\r";
	}

	function isDocumentMarker(marker:String):Bool {
		return column(at) == 0 && text.substr(at, 3) == marker && blankOrEnd(at + 3);
	}

	function column(position:Int):Int {
		var start = position;
		while (start > 0 && text.charCodeAt(start - 1) != 10) {
			start--;
		}
		return position - start;
	}

	function skipBlanks():Void {
		while (!atEnd() && isBlank(text.charAt(at))) {
			at++;
		}
	}

	function nextContent(inFlow:Bool):Bool {
		while (true) {
			var blanksStart = at;
			var tab = false;
			while (!atEnd() && isBlank(text.charAt(at))) {
				tab = tab || text.charAt(at) == "\t";
				at++;
			}
			if (atEnd()) {
				return false;
			}
			var c = text.charAt(at);
			if (c == "\n" || c == "\r") {
				at++;
				continue;
			}
			if (c == "#") {
				while (!atEnd() && text.charAt(at) != "\n") {
					at++;
				}
				continue;
			}
			if (tab && !inFlow && column(blanksStart) == 0) {
				fail(blanksStart, "a tab cannot indent a line: use spaces");
			}
			return true;
		}
	}

	function requireEndOfLine():Void {
		skipBlanks();
		if (!atEnd() && peek() != "\n" && peek() != "\r" && peek() != "#") {
			fail(at, "this text comes after a complete value");
		}
	}

	function checkIndicator(c:String, position:Int):Void {
		if (c == "&" || c == "*") {
			fail(position, "Fried YAML does not support anchors and aliases");
		}
		if (c == "!") {
			fail(position, "Fried YAML does not support tags");
		}
		if (c == "|" || c == ">") {
			fail(position, "Fried YAML does not support block scalars: write the text in double quotes with \\n");
		}
		if (c == "?" && blankOrEnd(position + 1)) {
			fail(position, "Fried YAML does not support complex keys");
		}
		if (c == "@" || c == "`" || c == "%") {
			fail(position, "the character '" + c + "' cannot start a plain value: put the text in quotes");
		}
	}

	function findKeyColon(from:Int):Int {
		if (from >= text.length) {
			return -1;
		}
		var c = text.charAt(from);
		var i = from;
		if (c == '"' || c == "'") {
			i++;
			while (i < text.length && text.charAt(i) != "\n") {
				if (c == '"' && text.charAt(i) == "\\") {
					i += 2;
					continue;
				}
				if (text.charAt(i) == c) {
					if (c == "'" && i + 1 < text.length && text.charAt(i + 1) == "'") {
						i += 2;
						continue;
					}
					break;
				}
				i++;
			}
			if (i >= text.length || text.charAt(i) != c) {
				return -1;
			}
			i++;
			while (i < text.length && isBlank(text.charAt(i))) {
				i++;
			}
			return i < text.length && text.charAt(i) == ":" && blankOrEnd(i + 1) ? i : -1;
		}
		if (c == "{" || c == "[") {
			return -1;
		}
		while (i < text.length && text.charAt(i) != "\n") {
			if (text.charAt(i) == "#" && i > from && isBlank(text.charAt(i - 1))) {
				return -1;
			}
			if (text.charAt(i) == ":" && blankOrEnd(i + 1)) {
				return i;
			}
			i++;
		}
		return -1;
	}

	function node():Dynamic {
		var col = column(at);
		var c = peek();
		if (c == "-" && blankOrEnd(at + 1)) {
			return sequence(col);
		}
		if (c == "{" || c == "[") {
			var value = flow();
			requireEndOfLine();
			return value;
		}
		if (findKeyColon(at) >= 0) {
			return mapping(col);
		}
		var value = scalar(false);
		requireEndOfLine();
		return value;
	}

	function sequence(col:Int):Dynamic {
		var result:Array<Dynamic> = [];
		while (true) {
			at++;
			skipBlanks();
			var item:Dynamic = null;
			if (atEnd() || peek() == "\n" || peek() == "\r" || peek() == "#") {
				if (nextContent(false) && column(at) > col) {
					item = node();
				}
			} else {
				item = node();
			}
			result.push(item);
			if (!nextContent(false)) {
				break;
			}
			var here = column(at);
			if (here < col || isDocumentMarker("---") || isDocumentMarker("...")) {
				break;
			}
			if (here > col) {
				fail(at, "the indentation does not match the list it follows");
			}
			if (!(peek() == "-" && blankOrEnd(at + 1))) {
				break;
			}
		}
		return result;
	}

	function readKey(colon:Int):String {
		var key:String;
		var c = peek();
		if (c == '"' || c == "'") {
			key = c == '"' ? doubleQuoted() : singleQuoted();
			skipBlanks();
		} else {
			checkIndicator(c, at);
			key = StringTools.rtrim(text.substring(at, colon));
			if (key == "") {
				fail(at, "a key is empty");
			}
			at = colon;
		}
		at++;
		return key;
	}

	function mapping(col:Int):Dynamic {
		var result:Dynamic = {};
		while (true) {
			var keyAt = at;
			var colon = findKeyColon(at);
			if (colon < 0) {
				fail(at, "a key followed by ':' is expected here");
			}
			var key = readKey(colon);
			if (Reflect.hasField(result, key)) {
				fail(keyAt, 'the key "$key" appears twice');
			}
			skipBlanks();
			var value:Dynamic = null;
			if (!atEnd() && peek() != "\n" && peek() != "\r" && peek() != "#") {
				value = inlineValue();
				requireEndOfLine();
			} else if (nextContent(false)) {
				var here = column(at);
				if (here > col) {
					value = node();
				} else if (here == col && peek() == "-" && blankOrEnd(at + 1)) {
					value = sequence(col);
				}
			}
			Reflect.setField(result, key, value);
			if (!nextContent(false)) {
				break;
			}
			var here = column(at);
			if (here < col || isDocumentMarker("---") || isDocumentMarker("...")) {
				break;
			}
			if (here > col) {
				fail(at, "the indentation does not match the map it follows");
			}
		}
		return result;
	}

	function inlineValue():Dynamic {
		var c = peek();
		if (c == "{" || c == "[") {
			return flow();
		}
		if (c == "-" && blankOrEnd(at + 1)) {
			fail(at, "a list cannot start on the line of a key: put it on the next line");
		}
		return scalar(false);
	}

	function scalar(inFlow:Bool):Dynamic {
		var c = peek();
		if (c == '"') {
			return doubleQuoted();
		}
		if (c == "'") {
			return singleQuoted();
		}
		checkIndicator(c, at);
		var start = at;
		while (!atEnd() && text.charAt(at) != "\n") {
			var d = text.charAt(at);
			if (d == "#" && at > start && isBlank(text.charAt(at - 1))) {
				break;
			}
			if (inFlow && (d == "," || d == "]" || d == "}")) {
				break;
			}
			at++;
		}
		var plain = text.substring(start, at);
		while (plain.length > 0 && (isBlank(plain.charAt(plain.length - 1)) || plain.charAt(plain.length - 1) == "\r")) {
			plain = plain.substr(0, plain.length - 1);
		}
		return resolvePlain(plain);
	}

	static function resolvePlain(plain:String):Dynamic {
		if (plain == "" || plain == "null" || plain == "~") {
			return null;
		}
		if (plain == "true") {
			return true;
		}
		if (plain == "false") {
			return false;
		}
		var number = matchNumber(plain);
		if (number == 0) {
			return plain;
		}
		var value = Std.parseFloat(plain);
		if (number == 1 && value >= -2147483648.0 && value <= 2147483647.0) {
			return Std.int(value);
		}
		return value;
	}

	// 0 when the text is not a number, 1 for a whole number and 2 for any other.
	static function matchNumber(s:String):Int {
		var i = 0;
		var n = s.length;
		if (i < n && s.charAt(i) == "-") {
			i++;
		}
		var before = 0;
		while (i < n && isDigit(s.charAt(i))) {
			i++;
			before++;
		}
		if (i == n) {
			return before > 0 ? 1 : 0;
		}
		var point = false;
		var after = 0;
		if (s.charAt(i) == ".") {
			point = true;
			i++;
			while (i < n && isDigit(s.charAt(i))) {
				i++;
				after++;
			}
		}
		if (point ? after == 0 : before == 0) {
			return 0;
		}
		if (i < n && (s.charAt(i) == "e" || s.charAt(i) == "E")) {
			i++;
			if (i < n && (s.charAt(i) == "-" || s.charAt(i) == "+")) {
				i++;
			}
			var digits = 0;
			while (i < n && isDigit(s.charAt(i))) {
				i++;
				digits++;
			}
			if (digits == 0) {
				return 0;
			}
		}
		return i == n ? 2 : 0;
	}

	function hex4():Int {
		var code = 0;
		for (_ in 0...4) {
			var digit = Std.parseInt("0x" + peek());
			if (peek() == "" || digit == null || !~/^[0-9a-fA-F]$/.match(peek())) {
				fail(at, "\\u needs four hexadecimal digits");
			}
			code = code * 16 + digit;
			at++;
		}
		return code;
	}

	function doubleQuoted():String {
		var start = at++;
		var out = new StringBuf();
		while (true) {
			if (atEnd() || peek() == "\n") {
				fail(start, "a string in double quotes is not closed on its line");
			}
			var c = text.charAt(at++);
			if (c == '"') {
				return out.toString();
			}
			if (c != "\\") {
				out.add(c);
				continue;
			}
			var e = peek();
			at++;
			switch (e) {
				case '"':
					out.add('"');
				case "\\":
					out.add("\\");
				case "/":
					out.add("/");
				case "b":
					out.addChar(8);
				case "f":
					out.addChar(12);
				case "n":
					out.add("\n");
				case "r":
					out.add("\r");
				case "t":
					out.add("\t");
				case "u":
					var code = hex4();
					if (code >= 0xD800 && code < 0xDC00) {
						if (peek() != "\\" || peek(1) != "u") {
							fail(at, "a high surrogate needs the low one after it");
						}
						at += 2;
						var low = hex4();
						if (low < 0xDC00 || low > 0xDFFF) {
							fail(at, "a high surrogate needs the low one after it");
						}
						code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
					} else if (code >= 0xDC00 && code <= 0xDFFF) {
						fail(at, "a low surrogate comes without its high one");
					}
					out.addChar(code);
				default:
					fail(at - 1, "this escape is unknown");
			}
		}
	}

	function singleQuoted():String {
		var start = at++;
		var out = new StringBuf();
		while (true) {
			if (atEnd() || peek() == "\n") {
				fail(start, "a string in single quotes is not closed on its line");
			}
			var c = text.charAt(at++);
			if (c == "'") {
				if (peek() == "'") {
					out.add("'");
					at++;
					continue;
				}
				return out.toString();
			}
			out.add(c);
		}
	}

	function skipFlowSpace(openedAt:Int):Void {
		if (!nextContent(true)) {
			fail(openedAt, "this collection is not closed");
		}
	}

	function flow():Dynamic {
		var openedAt = at;
		var isObject = peek() == "{";
		var close = isObject ? "}" : "]";
		at++;
		var object:Dynamic = {};
		var array:Array<Dynamic> = [];
		skipFlowSpace(openedAt);
		if (peek() == close) {
			at++;
			return isObject ? object : array;
		}
		while (true) {
			if (isObject) {
				var keyAt = at;
				var key:String;
				var c = peek();
				if (c == '"' || c == "'") {
					key = c == '"' ? doubleQuoted() : singleQuoted();
				} else {
					checkIndicator(c, at);
					var start = at;
					while (!atEnd() && text.charAt(at) != "\n" && !(text.charAt(at) == ":" && blankOrEnd(at + 1)) && text.charAt(at) != "," && text.charAt(at) != "}") {
						at++;
					}
					key = StringTools.rtrim(text.substring(start, at));
					if (key == "") {
						fail(keyAt, "a key is empty");
					}
				}
				skipFlowSpace(openedAt);
				if (peek() != ":") {
					fail(at, "a ':' is missing after the key");
				}
				at++;
				skipFlowSpace(openedAt);
				if (Reflect.hasField(object, key)) {
					fail(keyAt, 'the key "$key" appears twice');
				}
				Reflect.setField(object, key, flowValue());
			} else {
				array.push(flowValue());
			}
			skipFlowSpace(openedAt);
			if (peek() == ",") {
				at++;
				skipFlowSpace(openedAt);
				if (peek() == close) {
					fail(at, "a comma cannot come before the end of a collection");
				}
				continue;
			}
			if (peek() == close) {
				at++;
				return isObject ? object : array;
			}
			fail(at, "a ',' or '" + close + "' is missing");
		}
	}

	function flowValue():Dynamic {
		var c = peek();
		if (c == "{" || c == "[") {
			return flow();
		}
		return scalar(true);
	}
}
