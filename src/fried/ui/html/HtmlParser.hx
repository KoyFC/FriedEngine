package fried.ui.html;

// Reads the HTML the engine shows. It is forgiving where a browser is: an element with no end such as <link> or <img> needs no slash, an end tag that does not match closes what it can, and `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;` and numeric entities are decoded. What it repairs is reported with its place. The text inside <style> and <script> is kept as it is.
//
// An element that a browser would close by itself, such as a <li> before the next <li>, is not: every element but the ones with no content is closed by its author.
class HtmlParser {
	static var voidTags:Array<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"];
	static var rawTags:Array<String> = ["style", "script"];

	var text:String;
	var index:Int;
	var problem:(offset:Int, message:String, fix:String) -> Void;
	var stack:Array<HtmlNode>;

	// `problem` is told where something was repaired or left out, as an offset in the text.
	public static function parse(text:String, problem:(offset:Int, message:String, fix:String) -> Void):HtmlNode {
		return new HtmlParser(text, problem).run();
	}

	function new(text:String, problem:(offset:Int, message:String, fix:String) -> Void) {
		this.text = text;
		this.problem = problem;
		index = 0;
	}

	function run():HtmlNode {
		var root = new HtmlNode(HtmlNode.DOCUMENT, 0);
		stack = [root];
		while (index < text.length) {
			var open = text.indexOf("<", index);
			if (open < 0) {
				addText(index, text.length);
				break;
			}
			if (open > index) {
				addText(index, open);
			}
			index = open;
			if (startsWith("<!--")) {
				var end = text.indexOf("-->", index + 4);
				index = end < 0 ? text.length : end + 3;
			} else if (startsWith("<!") || startsWith("<?")) {
				var end = text.indexOf(">", index);
				index = end < 0 ? text.length : end + 1;
			} else if (startsWith("</")) {
				closeTag();
			} else if (isLetter(text.charCodeAt(index + 1))) {
				openTag();
			} else {
				addText(index, index + 1);
				index++;
			}
		}
		while (stack.length > 1) {
			var unclosed = stack.pop();
			problem(unclosed.offset, '<${unclosed.tag}> is never closed, so it ends with its parent', 'write </${unclosed.tag}>');
		}
		return root;
	}

	function openTag():Void {
		var start = index;
		index++;
		var name = readName(" \t\r\n/>").toLowerCase();
		var node = new HtmlNode(name, start);
		var isSelfClosed = false;
		var isClosed = false;
		while (index < text.length && !isClosed) {
			skipSpace();
			var code = text.charAt(index);
			if (code == ">") {
				index++;
				isClosed = true;
			} else if (code == "/") {
				index++;
				if (text.charAt(index) == ">") {
					index++;
					isSelfClosed = true;
					isClosed = true;
				}
			} else if (code == "") {
				break;
			} else {
				readAttribute(node);
			}
		}
		if (!isClosed) {
			problem(start, '<$name> is never closed with a >', "write >");
		}
		stack[stack.length - 1].children.push(node);
		if (isSelfClosed || voidTags.indexOf(name) >= 0) {
			return;
		}
		if (rawTags.indexOf(name) >= 0) {
			var end = indexOfIgnoringCase('</$name', index);
			var content = text.substring(index, end < 0 ? text.length : end);
			var raw = new HtmlNode(HtmlNode.TEXT, index);
			raw.text = content;
			node.children.push(raw);
			var close = end < 0 ? -1 : text.indexOf(">", end);
			index = close < 0 ? text.length : close + 1;
			return;
		}
		stack.push(node);
	}

	function readAttribute(node:HtmlNode):Void {
		var start = index;
		var name = readName(" \t\r\n/>=").toLowerCase();
		if (name == "") {
			index++;
			return;
		}
		skipSpace();
		var value = "";
		if (text.charAt(index) == "=") {
			index++;
			skipSpace();
			var quote = text.charAt(index);
			if (quote == '"' || quote == "'") {
				var end = text.indexOf(quote, index + 1);
				if (end < 0) {
					problem(index, "an attribute value is never closed", 'write a closing $quote');
					end = text.length;
				}
				value = decode(text.substring(index + 1, end));
				index = end + 1;
			} else {
				value = decode(readName(" \t\r\n>"));
			}
		}
		node.attributes.set(name, value);
		node.attributeOffsets.set(name, start);
	}

	function closeTag():Void {
		var end = text.indexOf(">", index);
		var name = StringTools.trim(text.substring(index + 2, end < 0 ? text.length : end)).toLowerCase();
		var at = index;
		index = end < 0 ? text.length : end + 1;
		var position = stack.length - 1;
		while (position > 0 && stack[position].tag != name) {
			position--;
		}
		if (position == 0) {
			problem(at, '</$name> closes nothing, so it is left out', "remove it");
			return;
		}
		while (stack.length > position + 1) {
			var unclosed = stack.pop();
			problem(unclosed.offset, '<${unclosed.tag}> is not closed before </$name>', 'write </${unclosed.tag}>');
		}
		stack.pop();
	}

	function addText(from:Int, to:Int):Void {
		var node = new HtmlNode(HtmlNode.TEXT, from);
		node.text = decode(text.substring(from, to));
		stack[stack.length - 1].children.push(node);
	}

	function readName(stops:String):String {
		var start = index;
		while (index < text.length && stops.indexOf(text.charAt(index)) < 0) {
			index++;
		}
		return text.substring(start, index);
	}

	function skipSpace():Void {
		while (index < text.length && " \t\r\n".indexOf(text.charAt(index)) >= 0) {
			index++;
		}
	}

	function startsWith(prefix:String):Bool {
		return text.substr(index, prefix.length) == prefix;
	}

	function indexOfIgnoringCase(needle:String, from:Int):Int {
		return text.toLowerCase().indexOf(needle.toLowerCase(), from);
	}

	static function isLetter(code:Null<Int>):Bool {
		return code != null && (code >= 65 && code <= 90 || code >= 97 && code <= 122);
	}

	static function decode(value:String):String {
		if (value.indexOf("&") < 0) {
			return value;
		}
		var result = new StringBuf();
		var index = 0;
		while (index < value.length) {
			var character = value.charAt(index);
			var end = character == "&" ? value.indexOf(";", index) : -1;
			if (end < 0 || end - index > 10) {
				result.add(character);
				index++;
				continue;
			}
			var name = value.substring(index + 1, end);
			var decoded = entity(name);
			if (decoded == null) {
				result.add(character);
				index++;
			} else {
				result.add(decoded);
				index = end + 1;
			}
		}
		return result.toString();
	}

	static function entity(name:String):Null<String> {
		switch (name) {
			case "amp":
				return "&";
			case "lt":
				return "<";
			case "gt":
				return ">";
			case "quot":
				return '"';
			case "apos":
				return "'";
			case "nbsp":
				return " ";
			case _:
		}
		if (name.charAt(0) == "#" && name.length > 1) {
			var code = name.charAt(1) == "x" || name.charAt(1) == "X" ? Std.parseInt("0x" + name.substr(2)) : Std.parseInt(name.substr(1));
			return code != null && code > 0 ? String.fromCharCode(code) : null;
		}
		return null;
	}
}
