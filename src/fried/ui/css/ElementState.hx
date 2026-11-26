package fried.ui.css;

// The pseudo-classes a selector can ask for, as bits of an element's states.
class ElementState {
	public static inline var HOVER:Int = 1;
	public static inline var ACTIVE:Int = 2;
	public static inline var FOCUS:Int = 4;
	public static inline var DISABLED:Int = 8;

	public static function fromName(name:String):Int {
		return switch (name) {
			case "hover": HOVER;
			case "active": ACTIVE;
			case "focus": FOCUS;
			case "disabled": DISABLED;
			case _: 0;
		}
	}
}
