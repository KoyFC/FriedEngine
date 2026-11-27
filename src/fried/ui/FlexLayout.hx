package fried.ui;

// Sizes and places the elements of a document: blocks that stack, and flex containers with a direction, a gap, justification, alignment and growth. There is no shrinking, so what does not fit overflows, and nothing is clipped.
//
// An element is laid out for the width its parent gives it, which gives its height, and its children are placed relative to its content box. The positions in the document come in one last walk, so a child is never moved once it is placed. Every size is a whole number of pixels.
class FlexLayout {
	// Which layout the widths an element prefers were worked out in.
	static var pass:Int = 0;

	// The root fills the viewport, as the screen a document is, and its margins are left around it.
	public static function layoutRoot(root:UIElement, width:Int, height:Int):Void {
		pass++;
		var style = root.style;
		layoutElement(root, width - style.marginLeft - style.marginRight, height - style.marginTop - style.marginBottom);
		place(root, style.marginLeft, style.marginTop);
	}

	// Gives the element a border box of this width and returns its height. `forcedHeight` is a border box height its parent decided, or -1 to let the content decide.
	static function layoutElement(element:UIElement, borderWidth:Int, forcedHeight:Int):Int {
		var style = element.style;
		element.boxWidth = borderWidth;
		var contentWidth = atLeastZero(borderWidth - style.horizontalExtras());
		var knownHeight = forcedHeight >= 0 ? atLeastZero(forcedHeight - style.verticalExtras()) : -1;
		var contentHeight:Int;
		if (element.kind == UIElement.TEXT) {
			contentHeight = layoutText(cast element, contentWidth);
		} else if (element.kind == UIElement.IMAGE) {
			var texture = cast(element, UIImage).texture;
			contentHeight = texture != null ? texture.height : 0;
		} else if (style.display == Style.FLEX) {
			contentHeight = layoutFlex(element, contentWidth, knownHeight);
		} else {
			contentHeight = layoutBlock(element, contentWidth, knownHeight);
		}
		var height = forcedHeight >= 0 ? forcedHeight : contentHeight + style.verticalExtras();
		height = clamp(height, style.minHeight, style.maxHeight, style.verticalExtras(), -1);
		element.boxHeight = height;
		return height;
	}

	static function layoutText(element:UIText, contentWidth:Int):Int {
		var font = element.style.font;
		if (font == null || element.text == null || element.text == "") {
			element.lines = [];
			element.lineWidths = [];
			return 0;
		}
		element.fit(font, contentWidth);
		return font.lineHeight * element.lines.length;
	}

	static function layoutBlock(element:UIElement, contentWidth:Int, knownHeight:Int):Int {
		var y = 0;
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

	static function layoutFlex(element:UIElement, contentWidth:Int, knownHeight:Int):Int {
		var container = element.style;
		var count = 0;
		for (child in element.children) {
			if (child.isDisplayed()) {
				count++;
			}
		}
		if (count == 0) {
			return 0;
		}
		return container.isColumn ? layoutColumn(element, count, contentWidth, knownHeight) : layoutRow(element, count, contentWidth, knownHeight);
	}

	static function layoutRow(element:UIElement, count:Int, contentWidth:Int, knownHeight:Int):Int {
		var container = element.style;
		var children = element.children;
		var used = container.gap * (count - 1);
		var grow = 0;
		for (item in children) {
			if (item.isDisplayed()) {
				var style = item.style;
				item.flexWidth = borderWidthOf(item, contentWidth, false);
				used += item.flexWidth + style.marginLeft + style.marginRight;
				grow += style.flexGrow;
			}
		}
		var free = atLeastZero(contentWidth - used);
		if (free > 0 && grow > 0) {
			for (item in children) {
				if (item.isDisplayed()) {
					item.flexWidth += Std.int(free * item.style.flexGrow / grow);
				}
			}
			free = 0;
		}

		var line = 0;
		for (item in children) {
			if (item.isDisplayed()) {
				item.flexHeight = layoutElement(item, item.flexWidth, definiteHeight(item, knownHeight));
				line = atLeast(line, item.flexHeight + item.style.marginTop + item.style.marginBottom);
			}
		}
		var cross = knownHeight >= 0 ? knownHeight : line;
		for (item in children) {
			if (item.isDisplayed()) {
				var style = item.style;
				var room = cross - style.marginTop - style.marginBottom;
				if (container.alignItems == Style.ALIGN_STRETCH && style.height.mode == Length.AUTO && item.flexHeight < room) {
					item.flexHeight = layoutElement(item, item.flexWidth, room);
				}
				item.flexOffset = crossOffset(container.alignItems, room - item.flexHeight);
			}
		}

		var x = 0;
		var spacing = container.gap;
		switch (container.justify) {
			case Style.JUSTIFY_CENTER:
				x = free >> 1;
			case Style.JUSTIFY_END:
				x = free;
			case Style.JUSTIFY_BETWEEN if (count > 1):
				spacing += Std.int(free / (count - 1));
			case _:
		}
		for (item in children) {
			if (item.isDisplayed()) {
				var style = item.style;
				item.relX = x + style.marginLeft;
				item.relY = style.marginTop + item.flexOffset;
				x += style.marginLeft + item.flexWidth + style.marginRight + spacing;
			}
		}
		return line;
	}

	static function layoutColumn(element:UIElement, count:Int, contentWidth:Int, knownHeight:Int):Int {
		var container = element.style;
		var children = element.children;
		var used = container.gap * (count - 1);
		var grow = 0;
		for (item in children) {
			if (item.isDisplayed()) {
				var isStretched = container.alignItems == Style.ALIGN_STRETCH && item.style.width.mode == Length.AUTO;
				item.flexWidth = borderWidthOf(item, contentWidth, isStretched);
				item.flexHeight = layoutElement(item, item.flexWidth, definiteHeight(item, knownHeight));
				used += item.flexHeight + item.style.marginTop + item.style.marginBottom;
				grow += item.style.flexGrow;
			}
		}
		var free = knownHeight >= 0 ? atLeastZero(knownHeight - used) : 0;
		if (free > 0 && grow > 0) {
			for (item in children) {
				if (item.isDisplayed()) {
					var share = Std.int(free * item.style.flexGrow / grow);
					if (share > 0) {
						item.flexHeight = layoutElement(item, item.flexWidth, item.flexHeight + share);
					}
				}
			}
			free = 0;
		}

		var y = 0;
		var spacing = container.gap;
		switch (container.justify) {
			case Style.JUSTIFY_CENTER:
				y = free >> 1;
			case Style.JUSTIFY_END:
				y = free;
			case Style.JUSTIFY_BETWEEN if (count > 1):
				spacing += Std.int(free / (count - 1));
			case _:
		}
		for (item in children) {
			if (item.isDisplayed()) {
				var style = item.style;
				var room = contentWidth - style.marginLeft - style.marginRight;
				item.relX = style.marginLeft + crossOffset(container.alignItems, room - item.flexWidth);
				item.relY = y + style.marginTop;
				y += style.marginTop + item.flexHeight + style.marginBottom + spacing;
			}
		}
		return used;
	}

	// How far an item sits along the cross axis in the room it has, which is stretched to fill when it has none left over.
	static function crossOffset(alignItems:Int, spare:Int):Int {
		return switch (alignItems) {
			case Style.ALIGN_CENTER: spare >> 1;
			case Style.ALIGN_END: spare;
			case _: 0;
		}
	}

	// The border box height the style fixes, or -1 when it is the content's to decide.
	static function definiteHeight(element:UIElement, containerHeight:Int):Int {
		var style = element.style;
		var height = style.height.resolve(containerHeight);
		return height >= 0 ? height + style.verticalExtras() : -1;
	}

	// The border box width of an element in a container whose content is `available` wide. An auto width fills the container when `fill` is set and is what the content wants otherwise.
	static function borderWidthOf(element:UIElement, available:Int, fill:Bool):Int {
		var style = element.style;
		var extras = style.horizontalExtras();
		var width = style.width.resolve(available);
		if (width >= 0) {
			width += extras;
		} else {
			width = fill ? available - style.marginLeft - style.marginRight : preferredWidth(element);
		}
		return clamp(width, style.minWidth, style.maxWidth, extras, available);
	}

	// The border box width an element takes with room to spare: the widest line of its text, the widest of its children, or the sum of them along a row.
	static function preferredWidth(element:UIElement):Int {
		if (element.intrinsicPass == pass) {
			return element.intrinsic;
		}
		var style = element.style;
		var content = 0;
		if (element.kind == UIElement.TEXT) {
			var font = style.font;
			var text = cast(element, UIText);
			if (font != null && text.text != null) {
				content = text.widest(font);
			}
		} else if (element.kind == UIElement.IMAGE) {
			var texture = cast(element, UIImage).texture;
			content = texture != null ? texture.width : 0;
		} else {
			var isRow = style.display == Style.FLEX && !style.isColumn;
			var count = 0;
			for (child in element.children) {
				if (!child.isDisplayed()) {
					continue;
				}
				var childStyle = child.style;
				var outer = preferredWidth(child) + childStyle.marginLeft + childStyle.marginRight;
				content = isRow ? content + outer : atLeast(content, outer);
				count++;
			}
			if (isRow && count > 1) {
				content += style.gap * (count - 1);
			}
		}
		var fixed = style.width.mode == Length.PX ? style.width.value : content;
		var width = fixed + style.horizontalExtras();
		element.intrinsic = width;
		element.intrinsicPass = pass;
		return width;
	}

	// Holds a border box size to the minimum and maximum the style gives, which are sizes of the content. A percentage is of `available`, or ignored when that is not known.
	static function clamp(size:Int, minimum:Length, maximum:Length, extras:Int, available:Int):Int {
		var result = size;
		var most = maximum.resolve(available);
		if (most >= 0 && result > most + extras) {
			result = most + extras;
		}
		var least = minimum.resolve(available);
		if (least >= 0 && result < least + extras) {
			result = least + extras;
		}
		return result;
	}

	static inline function atLeast(a:Int, b:Int):Int {
		return a > b ? a : b;
	}

	static inline function atLeastZero(value:Int):Int {
		return value > 0 ? value : 0;
	}

	static function place(element:UIElement, x:Int, y:Int):Void {
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
