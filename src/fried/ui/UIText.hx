package fried.ui;

// A run of text inside an element. It takes the style of its parent and is drawn in lines the layout breaks.
@:allow(fried.ui)
class UIText extends UIElement {
	public var text(default, set):String;

	var lines:Array<String>;
	var lineWidths:Array<Int>;

	// For a text with {{names}} in it: the pieces between them, and the names, where the nth name goes after the nth piece.
	var pieces:Null<Array<String>>;
	var names:Null<Array<String>>;

	public function new(text:String) {
		super("#text");
		this.text = text;
		lines = [];
		lineWidths = [];
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
		var remaining = template;
		var pattern = ~/\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}/;
		while (pattern.match(remaining)) {
			literal.push(pattern.matchedLeft());
			found.push(pattern.matched(1));
			remaining = pattern.matchedRight();
		}
		if (found.length == 0) {
			return found;
		}
		literal.push(remaining);
		pieces = literal;
		names = found;
		return found;
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
