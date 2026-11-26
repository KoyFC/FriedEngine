package fried.ui;

import fried.ui.css.ElementState;

// A box of a document, made from an HTML element. It is not a scene node: a document holds its elements and lays them out and draws them itself.
@:allow(fried.ui)
class UIElement {
	public var tag(default, null):String;
	public var id(default, null):Null<String>;
	public var classList(default, null):ClassList;
	public var parent(default, null):Null<UIElement>;
	public var children(default, null):Array<UIElement>;
	public var style(default, null):Style;

	// The pseudo-classes that hold now, as bits of ElementState.
	public var states(default, null):Int;

	// Left out of the layout and the drawing, like display: none.
	public var hidden(default, set):Bool;

	// Does not take a press, and matches :disabled.
	public var disabled(default, set):Bool;

	public var onClick:Null<Void->Void>;

	// The text of the element: the text it holds directly, which setting replaces.
	public var textContent(get, set):String;

	// The border box in document coordinates, set by the layout.
	public var boxX(default, null):Float;
	public var boxY(default, null):Float;
	public var boxWidth(default, null):Float;
	public var boxHeight(default, null):Float;

	// The position under the content box of the parent, and the widest the element wants to be, as the layout works them out.
	var relX:Float;
	var relY:Float;
	var intrinsic:Float;
	var intrinsicPass:Int;

	var document:Null<UIDocument>;

	// The method the HTML named in onclick, kept to say so when nothing binds it.
	var handlerName:Null<String>;
	var isStyleDirty:Bool;

	public function new(tag:String, id:Null<String> = null, classes:Array<String> = null) {
		this.tag = tag;
		this.id = id;
		classList = new ClassList(this, classes != null ? classes : []);
		children = [];
		style = new Style();
		states = 0;
		hidden = false;
		disabled = false;
		boxX = 0.0;
		boxY = 0.0;
		boxWidth = 0.0;
		boxHeight = 0.0;
		relX = 0.0;
		relY = 0.0;
		intrinsic = 0.0;
		intrinsicPass = 0;
		isStyleDirty = false;
	}

	public function appendChild(child:UIElement):Void {
		if (child.parent != null) {
			child.parent.children.remove(child);
		}
		child.parent = this;
		children.push(child);
		child.setDocument(document);
		styleChanged();
	}

	public function isDisplayed():Bool {
		return !hidden && style.display != Style.NONE;
	}

	function styleChanged():Void {
		if (document != null) {
			document.invalidateStyle(this);
		}
	}

	function setDocument(value:Null<UIDocument>):Void {
		document = value;
		for (child in children) {
			child.setDocument(value);
		}
	}

	// Sets or clears a pseudo-class, which makes the style be worked out again only when it changed.
	function setState(bit:Int, isOn:Bool):Void {
		if ((states & bit != 0) == isOn) {
			return;
		}
		states = isOn ? states | bit : states & ~bit;
		styleChanged();
	}

	function get_textContent():String {
		var text = [];
		for (child in children) {
			if (Std.isOfType(child, UIText)) {
				text.push(cast(child, UIText).text);
			}
		}
		return text.join(" ");
	}

	function set_textContent(value:String):String {
		for (child in children) {
			child.parent = null;
			child.setDocument(null);
		}
		children = [];
		appendChild(new UIText(value));
		return value;
	}

	function set_hidden(value:Bool):Bool {
		if (value != hidden) {
			hidden = value;
			if (document != null) {
				document.invalidateLayout();
			}
		}
		return value;
	}

	function set_disabled(value:Bool):Bool {
		disabled = value;
		setState(ElementState.DISABLED, value);
		return value;
	}
}
