package fried.ui;

import fried.io.Filesystem;
import fried.ui.html.HtmlNode;
import fried.ui.html.HtmlParser;

// An HTML file read and parsed, once for its path. What the parser has to repair, such as an element that was never closed, is reported with its line and column.
class HtmlSource {
	public var path(default, null):String;

	// The root of what the file parsed to, whose children are its top level elements.
	public var root(default, null):HtmlNode;

	var lines:SourceLines;

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
		var lines = new SourceLines(text);
		var root = HtmlParser.parse(text, (offset, message, fix) -> UIDiagnostics.report(path, lines.line(offset), lines.column(offset), message, fix));
		return new HtmlSource(path, root, lines);
	}

	function new(path:String, root:HtmlNode, lines:SourceLines) {
		this.path = path;
		this.root = root;
		this.lines = lines;
	}

	// Reports something about a node at its place in the file.
	public function report(node:HtmlNode, message:String, fix:String):Void {
		UIDiagnostics.report(path, lines.line(node.offset), lines.column(node.offset), message, fix);
	}
}
