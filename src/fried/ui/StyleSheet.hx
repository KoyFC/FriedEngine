package fried.ui;

import fried.io.Filesystem;
import fried.ui.css.CssParser;
import fried.ui.css.StyleRule;
import haxe.io.Path;

// A parsed CSS file. It is loaded once for its path and shared by every document and node that uses it, so the file is read and parsed a single time however many use it.
class StyleSheet {
	public var path(default, null):String;
	public var rules(default, null):Array<StyleRule>;

	// Family to the asset path of its font, resolved against the directory of the sheet.
	public var fontFaces(default, null):Map<String, String>;

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
			faces.set(family, Path.join([Path.directory(path), parsed.fontFaces.get(family)]));
		}
		return new StyleSheet(path, parsed.rules, faces);
	}

	function new(path:String, rules:Array<StyleRule>, fontFaces:Map<String, String>) {
		this.path = path;
		this.rules = rules;
		this.fontFaces = fontFaces;
	}
}
