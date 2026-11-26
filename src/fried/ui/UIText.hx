package fried.ui;

// A run of text inside an element. It takes the style of its parent and is drawn in lines the layout breaks.
@:allow(fried.ui)
class UIText extends UIElement {
	public var text(default, set):String;

	var lines:Array<String>;
	var lineWidths:Array<Int>;

	public function new(text:String) {
		super("#text");
		this.text = text;
		lines = [];
		lineWidths = [];
	}

	override function get_textContent():String {
		return text;
	}

	override function set_textContent(value:String):String {
		text = value;
		return value;
	}

	function set_text(value:String):String {
		if (value != text) {
			text = value;
			if (document != null) {
				document.invalidateLayout();
			}
		}
		return text;
	}
}
