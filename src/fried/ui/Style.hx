package fried.ui;

import fried.graphics.Color;
import fried.graphics.Font;
import fried.ui.css.CssProperties;
import fried.ui.css.Declaration;
import fried.ui.css.StyleValue;

// What an element's rules come to once the cascade and inheritance are applied.
class Style {
	public static inline var BLOCK:Int = 0;
	public static inline var FLEX:Int = 1;
	public static inline var NONE:Int = 2;

	public static inline var JUSTIFY_START:Int = 0;
	public static inline var JUSTIFY_CENTER:Int = 1;
	public static inline var JUSTIFY_END:Int = 2;
	public static inline var JUSTIFY_BETWEEN:Int = 3;

	public static inline var ALIGN_STRETCH:Int = 0;
	public static inline var ALIGN_START:Int = 1;
	public static inline var ALIGN_CENTER:Int = 2;
	public static inline var ALIGN_END:Int = 3;

	public static inline var TEXT_LEFT:Int = 0;
	public static inline var TEXT_CENTER:Int = 1;
	public static inline var TEXT_RIGHT:Int = 2;

	public var display:Int = BLOCK;
	public var isColumn:Bool = false;
	public var justify:Int = JUSTIFY_START;
	public var alignItems:Int = ALIGN_STRETCH;
	public var gap:Int = 0;

	// In sixteenths, so that 1 is 16.
	public var flexGrow:Int = 0;

	public var width:Length = Length.auto;
	public var height:Length = Length.auto;
	public var minWidth:Length = Length.auto;
	public var minHeight:Length = Length.auto;
	public var maxWidth:Length = Length.auto;
	public var maxHeight:Length = Length.auto;

	public var marginTop:Int = 0;
	public var marginRight:Int = 0;
	public var marginBottom:Int = 0;
	public var marginLeft:Int = 0;
	public var paddingTop:Int = 0;
	public var paddingRight:Int = 0;
	public var paddingBottom:Int = 0;
	public var paddingLeft:Int = 0;
	public var borderTop:Int = 0;
	public var borderRight:Int = 0;
	public var borderBottom:Int = 0;
	public var borderLeft:Int = 0;
	public var isBorderSolid:Bool = false;

	public var backgroundColor:Color = Color.rgba(0, 0, 0, 0);
	public var color:Color = Color.rgb(255, 255, 255);

	// A border without a color of its own is drawn in the text color.
	public var hasBorderColor:Bool = false;

	public var borderColor:Color = Color.rgb(0, 0, 0);
	public var fontFamily:Array<String> = [];
	public var fontSize:Int = 16;
	public var textAlign:Int = TEXT_LEFT;
	public var isVisible:Bool = true;
	// From 0 to 256, where 256 is opaque.
	public var opacity:Int = 256;

	// The font the family and size come to, which the resolver looks up once the declarations are in.
	public var font:Null<Font>;

	public function new() {}

	// Whether anything the layout reads differs, which is what decides if a change of style needs the layout done again. A color or an opacity does not.
	public function differsInLayout(other:Style):Bool {
		return display != other.display || isColumn != other.isColumn || justify != other.justify || alignItems != other.alignItems || gap != other.gap
			|| flexGrow != other.flexGrow || !same(width, other.width) || !same(height, other.height) || !same(minWidth, other.minWidth)
			|| !same(minHeight, other.minHeight) || !same(maxWidth, other.maxWidth) || !same(maxHeight, other.maxHeight) || marginTop != other.marginTop
			|| marginRight != other.marginRight || marginBottom != other.marginBottom || marginLeft != other.marginLeft || paddingTop != other.paddingTop
			|| paddingRight != other.paddingRight || paddingBottom != other.paddingBottom || paddingLeft != other.paddingLeft || borderTop != other.borderTop
			|| borderRight != other.borderRight || borderBottom != other.borderBottom || borderLeft != other.borderLeft || font != other.font;
	}

	static inline function same(a:Length, b:Length):Bool {
		return a == b || (a.mode == b.mode && a.value == b.value);
	}

	public function inheritFrom(parent:Style):Void {
		color = parent.color;
		fontFamily = parent.fontFamily;
		fontSize = parent.fontSize;
		textAlign = parent.textAlign;
		isVisible = parent.isVisible;
	}

	// What a border or a padding adds to the width and to the height of the content.
	public inline function horizontalExtras():Int {
		return paddingLeft + paddingRight + borderLeft + borderRight;
	}

	public inline function verticalExtras():Int {
		return paddingTop + paddingBottom + borderTop + borderBottom;
	}

	public function apply(declaration:Declaration):Void {
		var value = declaration.value;
		switch (declaration.property) {
			case CssProperties.DISPLAY:
				display = switch (keyword(value)) {
					case "flex": FLEX;
					case "none": NONE;
					case _: BLOCK;
				}
			case CssProperties.FLEX_DIRECTION:
				isColumn = keyword(value) == "column";
			case CssProperties.JUSTIFY_CONTENT:
				justify = switch (keyword(value)) {
					case "center": JUSTIFY_CENTER;
					case "flex-end": JUSTIFY_END;
					case "space-between": JUSTIFY_BETWEEN;
					case _: JUSTIFY_START;
				}
			case CssProperties.ALIGN_ITEMS:
				alignItems = switch (keyword(value)) {
					case "flex-start": ALIGN_START;
					case "center": ALIGN_CENTER;
					case "flex-end": ALIGN_END;
					case _: ALIGN_STRETCH;
				}
			case CssProperties.GAP:
				gap = pixels(value);
			case CssProperties.FLEX_GROW:
				flexGrow = Math.round(number(value) * 16);
			case CssProperties.WIDTH:
				width = Length.from(value);
			case CssProperties.HEIGHT:
				height = Length.from(value);
			case CssProperties.MIN_WIDTH:
				minWidth = Length.from(value);
			case CssProperties.MIN_HEIGHT:
				minHeight = Length.from(value);
			case CssProperties.MAX_WIDTH:
				maxWidth = Length.from(value);
			case CssProperties.MAX_HEIGHT:
				maxHeight = Length.from(value);
			case CssProperties.MARGIN_TOP:
				marginTop = pixels(value);
			case CssProperties.MARGIN_RIGHT:
				marginRight = pixels(value);
			case CssProperties.MARGIN_BOTTOM:
				marginBottom = pixels(value);
			case CssProperties.MARGIN_LEFT:
				marginLeft = pixels(value);
			case CssProperties.PADDING_TOP:
				paddingTop = pixels(value);
			case CssProperties.PADDING_RIGHT:
				paddingRight = pixels(value);
			case CssProperties.PADDING_BOTTOM:
				paddingBottom = pixels(value);
			case CssProperties.PADDING_LEFT:
				paddingLeft = pixels(value);
			case CssProperties.BORDER_TOP_WIDTH:
				borderTop = pixels(value);
			case CssProperties.BORDER_RIGHT_WIDTH:
				borderRight = pixels(value);
			case CssProperties.BORDER_BOTTOM_WIDTH:
				borderBottom = pixels(value);
			case CssProperties.BORDER_LEFT_WIDTH:
				borderLeft = pixels(value);
			case CssProperties.BORDER_COLOR:
				borderColor = colorOf(value);
				hasBorderColor = true;
			case CssProperties.BORDER_STYLE:
				isBorderSolid = keyword(value) == "solid";
			case CssProperties.BACKGROUND_COLOR:
				backgroundColor = colorOf(value);
			case CssProperties.COLOR:
				color = colorOf(value);
			case CssProperties.FONT_FAMILY:
				fontFamily = switch (value) {
					case Family(names): names;
					case _: fontFamily;
				}
			case CssProperties.FONT_SIZE:
				fontSize = Std.int(Math.max(1, pixels(value)));
			case CssProperties.TEXT_ALIGN:
				textAlign = switch (keyword(value)) {
					case "center": TEXT_CENTER;
					case "right": TEXT_RIGHT;
					case _: TEXT_LEFT;
				}
			case CssProperties.VISIBILITY:
				isVisible = keyword(value) != "hidden";
			case CssProperties.OPACITY:
				opacity = Math.round(Math.min(1.0, number(value)) * 256);
			case _:
		}
	}

	// A border whose style is none has no width, whatever it was given.
	public function settle():Void {
		if (!isBorderSolid) {
			borderTop = 0;
			borderRight = 0;
			borderBottom = 0;
			borderLeft = 0;
		}
	}

	static function keyword(value:StyleValue):String {
		return switch (value) {
			case Keyword(name): name;
			case _: "";
		}
	}

	static function pixels(value:StyleValue):Int {
		return switch (value) {
			case Px(amount): Math.round(amount);
			case _: 0;
		}
	}

	static function number(value:StyleValue):Float {
		return switch (value) {
			case Number(amount): amount;
			case _: 0.0;
		}
	}

	static function colorOf(value:StyleValue):Color {
		return switch (value) {
			case ColorValue(color): color;
			case _: Color.rgb(0, 0, 0);
		}
	}
}
