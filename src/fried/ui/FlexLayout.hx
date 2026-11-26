package fried.ui;

import fried.graphics.TextLayout;
import fried.ui.css.StyleValue;

// Sizes and places the elements of a document: blocks that stack, and flex containers with a direction, a gap, justification, alignment and growth. There is no shrinking, so what does not fit overflows, and nothing is clipped.
//
// An element is laid out for the width its parent gives it, which gives its height, and its children are placed relative to its content box. The positions in the document come in one last walk, so a child is never moved once it is placed.
class FlexLayout {
	// Which layout the widths an element prefers were worked out in.
	static var pass:Int = 0;

	// The root fills the viewport, as the screen a document is, and its margins are left around it.
	public static function layoutRoot(root:UIElement, width:Float, height:Float):Void {
		pass++;
		var style = root.style;
		layoutElement(root, width - style.marginLeft - style.marginRight, height - style.marginTop - style.marginBottom);
		place(root, style.marginLeft, style.marginTop);
	}

	// Gives the element a border box of this width and returns its height. `forcedHeight` is a border box height its parent decided, or -1 to let the content decide.
	static function layoutElement(element:UIElement, borderWidth:Float, forcedHeight:Float):Float {
		var style = element.style;
		element.boxWidth = borderWidth;
		var contentWidth = Math.max(0.0, borderWidth - style.horizontalExtras());
		var knownHeight = forcedHeight >= 0 ? Math.max(0.0, forcedHeight - style.verticalExtras()) : -1.0;
		var contentHeight:Float;
		if (Std.isOfType(element, UIText)) {
			contentHeight = layoutText(cast element, contentWidth);
		} else if (Std.isOfType(element, UIImage)) {
			var texture = cast(element, UIImage).texture;
			contentHeight = texture != null ? texture.height : 0.0;
		} else if (style.display == Style.FLEX) {
			contentHeight = layoutFlex(element, contentWidth, knownHeight);
		} else {
			contentHeight = layoutBlock(element, contentWidth, knownHeight);
		}
		var height = forcedHeight >= 0 ? forcedHeight : contentHeight + style.verticalExtras();
		height = clamp(height, style.minHeight, style.maxHeight, style.verticalExtras(), -1.0);
		element.boxHeight = height;
		return height;
	}

	static function layoutText(element:UIText, contentWidth:Float):Float {
		var font = element.style.font;
		if (font == null || element.text == null || element.text == "") {
			element.lines = [];
			element.lineWidths = [];
			return 0.0;
		}
		element.lines = TextLayout.breakLines(font, element.text, Std.int(contentWidth));
		element.lineWidths = [for (line in element.lines) font.measureWidth(line)];
		return font.lineHeight * element.lines.length;
	}

	static function layoutBlock(element:UIElement, contentWidth:Float, knownHeight:Float):Float {
		var y = 0.0;
		for (child in element.children) {
			if (!child.isDisplayed()) {
				continue;
			}
			var style = child.style;
			var width = borderWidthOf(child, contentWidth, true);
			var height = layoutElement(child, width, definiteHeight(child, knownHeight));
			child.relX = style.marginLeft;
			child.relY = y + style.marginTop;
			y += style.marginTop + height + style.marginBottom;
		}
		return y;
	}

	static function layoutFlex(element:UIElement, contentWidth:Float, knownHeight:Float):Float {
		var items = [for (child in element.children) if (child.isDisplayed()) child];
		if (items.length == 0) {
			return 0.0;
		}
		return element.style.isColumn ? layoutColumn(element, items, contentWidth, knownHeight) : layoutRow(element, items, contentWidth, knownHeight);
	}

	static function layoutRow(element:UIElement, items:Array<UIElement>, contentWidth:Float, knownHeight:Float):Float {
		var container = element.style;
		var widths = [for (item in items) borderWidthOf(item, contentWidth, false)];
		var used = container.gap * (items.length - 1);
		var grow = 0.0;
		for (index in 0...items.length) {
			used += widths[index] + items[index].style.marginLeft + items[index].style.marginRight;
			grow += items[index].style.flexGrow;
		}
		var free = Math.max(0.0, contentWidth - used);
		if (free > 0 && grow > 0) {
			for (index in 0...items.length) {
				widths[index] += free * items[index].style.flexGrow / grow;
			}
			free = 0.0;
		}

		var heights = [];
		var line = 0.0;
		for (index in 0...items.length) {
			var item = items[index];
			var height = layoutElement(item, widths[index], definiteHeight(item, knownHeight));
			heights.push(height);
			line = Math.max(line, height + item.style.marginTop + item.style.marginBottom);
		}
		var cross = knownHeight >= 0 ? knownHeight : line;

		var offsets = [];
		for (index in 0...items.length) {
			var item = items[index];
			var style = item.style;
			var room = cross - style.marginTop - style.marginBottom;
			if (container.alignItems == Style.ALIGN_STRETCH && style.height == Auto && heights[index] < room) {
				heights[index] = layoutElement(item, widths[index], room);
			}
			offsets.push(crossOffset(container.alignItems, room - heights[index]));
		}

		var x = 0.0;
		var spacing = container.gap;
		switch (container.justify) {
			case Style.JUSTIFY_CENTER:
				x = free / 2;
			case Style.JUSTIFY_END:
				x = free;
			case Style.JUSTIFY_BETWEEN if (items.length > 1):
				spacing += free / (items.length - 1);
			case _:
		}
		for (index in 0...items.length) {
			var item = items[index];
			item.relX = x + item.style.marginLeft;
			item.relY = item.style.marginTop + offsets[index];
			x += item.style.marginLeft + widths[index] + item.style.marginRight + spacing;
		}
		return line;
	}

	static function layoutColumn(element:UIElement, items:Array<UIElement>, contentWidth:Float, knownHeight:Float):Float {
		var container = element.style;
		var widths = [];
		for (item in items) {
			var isStretched = container.alignItems == Style.ALIGN_STRETCH && item.style.width == Auto;
			widths.push(borderWidthOf(item, contentWidth, isStretched));
		}
		var heights = [];
		var used = container.gap * (items.length - 1);
		var grow = 0.0;
		for (index in 0...items.length) {
			var item = items[index];
			var height = layoutElement(item, widths[index], definiteHeight(item, knownHeight));
			heights.push(height);
			used += height + item.style.marginTop + item.style.marginBottom;
			grow += item.style.flexGrow;
		}
		var free = knownHeight >= 0 ? Math.max(0.0, knownHeight - used) : 0.0;
		if (free > 0 && grow > 0) {
			for (index in 0...items.length) {
				var share = free * items[index].style.flexGrow / grow;
				if (share > 0) {
					heights[index] = layoutElement(items[index], widths[index], heights[index] + share);
				}
			}
			free = 0.0;
		}

		var y = 0.0;
		var spacing = container.gap;
		switch (container.justify) {
			case Style.JUSTIFY_CENTER:
				y = free / 2;
			case Style.JUSTIFY_END:
				y = free;
			case Style.JUSTIFY_BETWEEN if (items.length > 1):
				spacing += free / (items.length - 1);
			case _:
		}
		for (index in 0...items.length) {
			var item = items[index];
			var style = item.style;
			var room = contentWidth - style.marginLeft - style.marginRight;
			item.relX = style.marginLeft + crossOffset(container.alignItems, room - widths[index]);
			item.relY = y + style.marginTop;
			y += style.marginTop + heights[index] + style.marginBottom + spacing;
		}
		return used;
	}

	// How far an item sits along the cross axis in the room it has, which is stretched to fill when it has none left over.
	static function crossOffset(alignItems:Int, spare:Float):Float {
		return switch (alignItems) {
			case Style.ALIGN_CENTER: spare / 2;
			case Style.ALIGN_END: spare;
			case _: 0.0;
		}
	}

	// The border box height the style fixes, or -1 when it is the content's to decide.
	static function definiteHeight(element:UIElement, containerHeight:Float):Float {
		var style = element.style;
		return switch (style.height) {
			case Px(value): value + style.verticalExtras();
			case Percent(value) if (containerHeight >= 0): containerHeight * value / 100 + style.verticalExtras();
			case _: -1.0;
		}
	}

	// The border box width of an element in a container whose content is `available` wide. An auto width fills the container when `fill` is set and is what the content wants otherwise.
	static function borderWidthOf(element:UIElement, available:Float, fill:Bool):Float {
		var style = element.style;
		var extras = style.horizontalExtras();
		var width:Float;
		switch (style.width) {
			case Px(value):
				width = value + extras;
			case Percent(value):
				width = available * value / 100 + extras;
			case _:
				width = fill ? available - style.marginLeft - style.marginRight : preferredWidth(element);
		}
		return clamp(width, style.minWidth, style.maxWidth, extras, available);
	}

	// The border box width an element takes with room to spare: the widest line of its text, the widest of its children, or the sum of them along a row.
	static function preferredWidth(element:UIElement):Float {
		if (element.intrinsicPass == pass) {
			return element.intrinsic;
		}
		var style = element.style;
		var content = 0.0;
		if (Std.isOfType(element, UIText)) {
			var font = style.font;
			var text = cast(element, UIText).text;
			if (font != null && text != null) {
				for (line in text.split("\n")) {
					content = Math.max(content, font.measureWidth(line));
				}
			}
		} else if (Std.isOfType(element, UIImage)) {
			var texture = cast(element, UIImage).texture;
			content = texture != null ? texture.width : 0.0;
		} else {
			var isRow = style.display == Style.FLEX && !style.isColumn;
			var count = 0;
			for (child in element.children) {
				if (!child.isDisplayed()) {
					continue;
				}
				var childStyle = child.style;
				var outer = preferredWidth(child) + childStyle.marginLeft + childStyle.marginRight;
				content = isRow ? content + outer : Math.max(content, outer);
				count++;
			}
			if (isRow && count > 1) {
				content += style.gap * (count - 1);
			}
		}
		var width = switch (style.width) {
			case Px(value): value + style.horizontalExtras();
			case _: content + style.horizontalExtras();
		}
		element.intrinsic = width;
		element.intrinsicPass = pass;
		return width;
	}

	// Holds a border box size to the minimum and maximum the style gives, which are sizes of the content. A percentage is of `available`, or ignored when that is not known.
	static function clamp(size:Float, minimum:StyleValue, maximum:StyleValue, extras:Float, available:Float):Float {
		var result = size;
		switch (maximum) {
			case Px(value):
				result = Math.min(result, value + extras);
			case Percent(value) if (available >= 0):
				result = Math.min(result, available * value / 100 + extras);
			case _:
		}
		switch (minimum) {
			case Px(value):
				result = Math.max(result, value + extras);
			case Percent(value) if (available >= 0):
				result = Math.max(result, available * value / 100 + extras);
			case _:
		}
		return result;
	}

	static function place(element:UIElement, x:Float, y:Float):Void {
		element.boxX = x;
		element.boxY = y;
		var style = element.style;
		var contentX = x + style.borderLeft + style.paddingLeft;
		var contentY = y + style.borderTop + style.paddingTop;
		for (child in element.children) {
			if (child.isDisplayed()) {
				place(child, contentX + child.relX, contentY + child.relY);
			}
		}
	}
}
