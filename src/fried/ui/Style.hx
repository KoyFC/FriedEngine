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
	public var gap:Float = 0.0;
	public var flexGrow:Float = 0.0;

	public var width:StyleValue = Auto;
	public var height:StyleValue = Auto;
	public var minWidth:StyleValue = Auto;
	public var minHeight:StyleValue = Auto;
	public var maxWidth:StyleValue = Auto;
	public var maxHeight:StyleValue = Auto;

	public var marginTop:Float = 0.0;
	public var marginRight:Float = 0.0;
	public var marginBottom:Float = 0.0;
	public var marginLeft:Float = 0.0;
	public var paddingTop:Float = 0.0;
	public var paddingRight:Float = 0.0;
	public var paddingBottom:Float = 0.0;
	public var paddingLeft:Float = 0.0;
	public var borderTop:Float = 0.0;
	public var borderRight:Float = 0.0;
	public var borderBottom:Float = 0.0;
	public var borderLeft:Float = 0.0;
	public var isBorderSolid:Bool = false;

	public var backgroundColor:Color = Color.rgba(0, 0, 0, 0);
	public var color:Color = Color.rgb(255, 255, 255);

	// A border without a color of its own is drawn in the text color.
	public var hasBorderColor:Bool = false;

	public var borderColor:Color = Color.rgb(0, 0, 0);
	public var fontFamily:Array<String> = [];
	public var fontSize:Float = 16.0;
	public var textAlign:Int = TEXT_LEFT;
	public var isVisible:Bool = true;
	public var opacity:Float = 1.0;

	// The font the family and size come to, which the resolver looks up once the declarations are in.
	public var font:Null<Font>;

	public function new() {}

	public function inheritFrom(parent:Style):Void {
		color = parent.color;
		fontFamily = parent.fontFamily;
		fontSize = parent.fontSize;
		textAlign = parent.textAlign;
		isVisible = parent.isVisible;
	}

	// What a border or a padding adds to the width and to the height of the content.
	public inline function horizontalExtras():Float {
		return paddingLeft + paddingRight + borderLeft + borderRight;
	}

	public inline function verticalExtras():Float {
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
				flexGrow = number(value);
			case CssProperties.WIDTH:
				width = value;
			case CssProperties.HEIGHT:
				height = value;
			case CssProperties.MIN_WIDTH:
				minWidth = value;
			case CssProperties.MIN_HEIGHT:
				minHeight = value;
			case CssProperties.MAX_WIDTH:
				maxWidth = value;
			case CssProperties.MAX_HEIGHT:
				maxHeight = value;
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
				fontSize = Math.max(1.0, pixels(value));
			case CssProperties.TEXT_ALIGN:
				textAlign = switch (keyword(value)) {
					case "center": TEXT_CENTER;
					case "right": TEXT_RIGHT;
					case _: TEXT_LEFT;
				}
			case CssProperties.VISIBILITY:
				isVisible = keyword(value) != "hidden";
			case CssProperties.OPACITY:
				opacity = Math.min(1.0, number(value));
			case _:
		}
	}

	// A border whose style is none has no width, whatever it was given.
	public function settle():Void {
		if (!isBorderSolid) {
			borderTop = 0.0;
			borderRight = 0.0;
			borderBottom = 0.0;
			borderLeft = 0.0;
		}
	}

	static function keyword(value:StyleValue):String {
		return switch (value) {
			case Keyword(name): name;
			case _: "";
		}
	}

	static function pixels(value:StyleValue):Float {
		return switch (value) {
			case Px(amount): amount;
			case _: 0.0;
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
