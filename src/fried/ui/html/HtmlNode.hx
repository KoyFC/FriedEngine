package fried.ui.html;

// An element or a run of text of an HTML file, with where it starts in the file.
class HtmlNode {
	public static inline var TEXT:String = "#text";
	public static inline var DOCUMENT:String = "#document";

	// The element's name in lower case, or TEXT, or DOCUMENT for the root.
	public var tag(default, null):String;

	// What a text says, with its entities decoded.
	public var text:String;

	public var attributes(default, null):Map<String, String>;

	// Where each attribute's name is in the file.
	public var attributeOffsets(default, null):Map<String, Int>;

	public var children(default, null):Array<HtmlNode>;

	// Where the node starts in the file.
	public var offset(default, null):Int;

	public var isText(get, never):Bool;

	public function new(tag:String, offset:Int) {
		this.tag = tag;
		this.offset = offset;
		text = "";
		attributes = new Map();
		attributeOffsets = new Map();
		children = [];
	}

	public function get(name:String):Null<String> {
		return attributes.get(name);
	}

	public function exists(name:String):Bool {
		return attributes.exists(name);
	}

	public function elements():Array<HtmlNode> {
		return children.filter(child -> !child.isText);
	}

	public function firstElement(name:String):Null<HtmlNode> {
		for (child in children) {
			if (child.tag == name) {
				return child;
			}
		}
		return null;
	}

	function get_isText():Bool {
		return tag == TEXT;
	}
}
