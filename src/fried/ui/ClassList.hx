package fried.ui;

// The classes of an element, which the stylesheet selects it by. Changing them makes the element's style be worked out again.
class ClassList {
	public var names(default, null):Array<String>;

	var owner:UIElement;

	public function new(owner:UIElement, names:Array<String>) {
		this.owner = owner;
		this.names = names;
	}

	public function contains(name:String):Bool {
		return names.indexOf(name) >= 0;
	}

	public function add(name:String):Void {
		if (!contains(name)) {
			names.push(name);
			owner.styleChanged();
		}
	}

	public function remove(name:String):Void {
		if (names.remove(name)) {
			owner.styleChanged();
		}
	}

	// Adds the class when it is absent and removes it when present, or sets it to `force` when given. Returns whether the element has it afterward.
	public function toggle(name:String, ?force:Bool):Bool {
		var shouldHave = force != null ? force : !contains(name);
		if (shouldHave) {
			add(name);
		} else {
			remove(name);
		}
		return shouldHave;
	}
}
