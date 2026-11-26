package fried.ui;

import fried.io.Filesystem;

// An HTML file read and parsed, once for its path. It has to be well formed, so an element with no end such as <link> or <img> is written with a closing slash.
class HtmlSource {
	public var path(default, null):String;

	// The XML document the file parsed to.
	public var xml(default, null):Xml;

	static var byPath:Map<String, HtmlSource> = new Map();

	public static function from(path:String):HtmlSource {
		var cached = byPath.get(path);
		if (cached != null) {
			return cached;
		}
		var source = parse(path, Filesystem.readBytes(path).toString());
		byPath.set(path, source);
		return source;
	}

	public static function parse(path:String, text:String):HtmlSource {
		var xml = try {
			Xml.parse(text);
		} catch (error:Dynamic) {
			throw '$path: the HTML is not well formed, so it cannot be read: $error';
		}
		return new HtmlSource(path, xml);
	}

	function new(path:String, xml:Xml) {
		this.path = path;
		this.xml = xml;
	}
}
