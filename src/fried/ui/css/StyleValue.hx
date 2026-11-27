package fried.ui.css;

import fried.graphics.Color;

// What a declaration holds after its value is parsed. A length is already in pixels or a percentage.
enum StyleValue {
	Px(value:Float);
	Percent(value:Float);
	Auto;
	ColorValue(color:Color);
	Keyword(name:String);
	Number(value:Float);
	Family(names:Array<String>);
	// A gradient from one color to the other, along the width when horizontal and along the height otherwise.
	Gradient(isHorizontal:Bool, from:Color, to:Color);
	// A shadow with no blur, as far over and down as it says.
	Shadow(x:Float, y:Float, color:Color);
}
