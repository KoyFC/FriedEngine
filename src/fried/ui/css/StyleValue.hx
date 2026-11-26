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
}
