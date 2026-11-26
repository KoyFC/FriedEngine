package fried.ui;

import fried.graphics.Font;
import fried.io.Assets;
import fried.ui.css.StyleRule;

private class Match {
	public var rule:StyleRule;
	public var sheet:Int;

	public function new(rule:StyleRule, sheet:Int) {
		this.rule = rule;
		this.sheet = sheet;
	}
}

// Works out the style of an element from the sheets of its document: the rules that match it, laid over one another by sheet, then specificity, then place in the sheet, on top of what it inherits.
class StyleResolver {
	// The most sizes of one family a document may use before it is told, since each size is an atlas of glyphs on the device.
	static inline var SIZES_PER_FAMILY:Int = 4;

	static var matches:Array<Match> = [];

	public static function resolve(element:UIElement, sheets:Array<StyleSheet>, sizes:Map<String, Array<Int>>, path:String):Void {
		var style = new Style();
		var parent = element.parent;
		if (parent != null) {
			style.inheritFrom(parent.style);
		}
		if (!Std.isOfType(element, UIText)) {
			matches.resize(0);
			for (index in 0...sheets.length) {
				for (rule in sheets[index].rules) {
					if (rule.selector.matches(element)) {
						matches.push(new Match(rule, index));
					}
				}
			}
			matches.sort(compare);
			for (match in matches) {
				for (declaration in match.rule.declarations) {
					style.apply(declaration);
				}
			}
			style.settle();
		}
		style.font = fontFor(style, sheets, sizes, path);
		element.style = style;
	}

	static function compare(a:Match, b:Match):Int {
		if (a.sheet != b.sheet) {
			return a.sheet - b.sheet;
		}
		if (a.rule.selector.specificity != b.rule.selector.specificity) {
			return a.rule.selector.specificity - b.rule.selector.specificity;
		}
		return a.rule.order - b.rule.order;
	}

	static function fontFor(style:Style, sheets:Array<StyleSheet>, sizes:Map<String, Array<Int>>, path:String):Font {
		var size = Std.int(Math.round(style.fontSize));
		for (family in style.fontFamily) {
			var index = sheets.length - 1;
			while (index >= 0) {
				var fontPath = sheets[index].fontFaces.get(family);
				if (fontPath != null) {
					noteSize(family, size, sizes, path);
					return Font.from(fontPath, size);
				}
				index--;
			}
		}
		UIDiagnostics.report(path, 0, 0, 'no @font-face for the font-family ${style.fontFamily.join(", ")}, so the engine font is used', 'declare it with @font-face { font-family: "Name"; src: url("file.ttf"); }');
		return Font.from(Assets.engine("NunitoSans.ttf"), size);
	}

	static function noteSize(family:String, size:Int, sizes:Map<String, Array<Int>>, path:String):Void {
		var used = sizes.get(family);
		if (used == null) {
			used = [];
			sizes.set(family, used);
		}
		if (used.indexOf(size) < 0) {
			used.push(size);
			if (used.length == SIZES_PER_FAMILY + 1) {
				UIDiagnostics.report(path, 0, 0, 'the font $family is used at more than $SIZES_PER_FAMILY sizes, and each size is an atlas of glyphs in memory', "reuse the same few font sizes");
			}
		}
	}
}
