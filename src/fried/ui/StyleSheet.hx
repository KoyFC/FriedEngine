package fried.ui;

import fried.io.Filesystem;
import fried.ui.css.CssParser;
import fried.ui.css.StyleRule;

// A parsed CSS file. It is loaded once for its path and shared by every document and node that uses it, so the file is read and parsed a single time however many use it.
class StyleSheet {
	public var path(default, null):String;
	public var rules(default, null):Array<StyleRule>;

	// Family to the asset path of its font, which the sheet wrote relative to its own directory or as `engine:` or `game:` followed by a path.
	public var fontFaces(default, null):Map<String, String>;

	// The rules by what their last compound selector names, so an element is only tried against the rules that could be about it: the ones for its id, its classes and its tag, and the ones that name none of them.
	public var universal(default, null):Array<StyleRule>;

	public var byTag(default, null):Map<String, Array<StyleRule>>;
	public var byId(default, null):Map<String, Array<StyleRule>>;
	public var byClass(default, null):Map<String, Array<StyleRule>>;

	static var byPath:Map<String, StyleSheet> = new Map();

	public static function from(path:String):StyleSheet {
		var cached = byPath.get(path);
		if (cached != null) {
			return cached;
		}
		var sheet = parse(path, Filesystem.readBytes(path).toString());
		byPath.set(path, sheet);
		return sheet;
	}

	// A sheet that is not read from a file, such as a <style> in a document, and so is not shared.
	public static function parse(path:String, text:String):StyleSheet {
		var parsed = CssParser.parse(path, text);
		var faces = new Map<String, String>();
		for (family in parsed.fontFaces.keys()) {
			faces.set(family, UIPaths.resolve(path, parsed.fontFaces.get(family)));
		}
		return new StyleSheet(path, parsed.rules, faces);
	}

	function new(path:String, rules:Array<StyleRule>, fontFaces:Map<String, String>) {
		this.path = path;
		this.rules = rules;
		this.fontFaces = fontFaces;
		universal = [];
		byTag = new Map();
		byId = new Map();
		byClass = new Map();
		for (rule in rules) {
			var last = rule.selector.parts[rule.selector.parts.length - 1];
			if (last.id != null) {
				add(byId, last.id, rule);
			} else if (last.classes.length > 0) {
				add(byClass, last.classes[0], rule);
			} else if (last.tag != null && last.tag != "*") {
				add(byTag, last.tag, rule);
			} else {
				universal.push(rule);
			}
		}
	}

	static function add(index:Map<String, Array<StyleRule>>, key:String, rule:StyleRule):Void {
		var list = index.get(key);
		if (list == null) {
			list = [];
			index.set(key, list);
		}
		list.push(rule);
	}
}
