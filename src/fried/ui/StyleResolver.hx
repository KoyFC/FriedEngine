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

private class FontEntry {
	public var families:Array<String>;
	public var size:Int;
	public var sheets:Array<StyleSheet>;
	public var font:Font;

	public function new(families:Array<String>, size:Int, sheets:Array<StyleSheet>, font:Font) {
		this.families = families;
		this.size = size;
		this.sheets = sheets;
		this.font = font;
	}
}

// Works out the style of an element from the sheets of its document: the rules that match it, laid over one another by specificity, then by sheet, then by place in the sheet, on top of what it inherits.
class StyleResolver {
	// The most sizes of one family a document may use before it is told, since each size is an atlas of glyphs on the device.
	static inline var SIZES_PER_FAMILY:Int = 4;

	static var matches:Array<Match> = [];
	static var fonts:Array<FontEntry> = [];

	public static function resolve(element:UIElement, sheets:Array<StyleSheet>, sizes:Map<String, Array<Int>>, path:String):Void {
		var style = new Style();
		var parent = element.parent;
		if (parent != null) {
			style.inheritFrom(parent.style);
		}
		if (element.kind != UIElement.TEXT) {
			matches.resize(0);
			for (index in 0...sheets.length) {
				var sheet = sheets[index];
				consider(sheet.universal, element, index);
				consider(sheet.byTag.get(element.tag), element, index);
				if (element.id != null) {
					consider(sheet.byId.get(element.id), element, index);
				}
				for (name in element.classList.names) {
					consider(sheet.byClass.get(name), element, index);
				}
			}
			if (matches.length > 1) {
				matches.sort(compare);
			}
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

	static function consider(rules:Null<Array<StyleRule>>, element:UIElement, sheet:Int):Void {
		if (rules == null) {
			return;
		}
		for (rule in rules) {
			if (rule.selector.matches(element)) {
				matches.push(new Match(rule, sheet));
			}
		}
	}

	static function compare(a:Match, b:Match):Int {
		if (a.rule.selector.specificity != b.rule.selector.specificity) {
			return a.rule.selector.specificity - b.rule.selector.specificity;
		}
		if (a.sheet != b.sheet) {
			return a.sheet - b.sheet;
		}
		return a.rule.order - b.rule.order;
	}

	static function fontFor(style:Style, sheets:Array<StyleSheet>, sizes:Map<String, Array<Int>>, path:String):Font {
		var size = style.fontSize;
		for (entry in fonts) {
			if (entry.families == style.fontFamily && entry.size == size && entry.sheets == sheets) {
				return entry.font;
			}
		}
		var font = findFont(style, size, sheets, sizes, path);
		fonts.push(new FontEntry(style.fontFamily, size, sheets, font));
		return font;
	}

	static function findFont(style:Style, size:Int, sheets:Array<StyleSheet>, sizes:Map<String, Array<Int>>, path:String):Font {
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
