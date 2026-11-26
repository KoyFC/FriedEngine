package fried.ui;

// A <button>: it takes a press, and a gamepad or keyboard can focus it.
class UIButton extends UIElement {
	public function new(id:Null<String> = null, classes:Array<String> = null) {
		super("button", id, classes);
	}
}
