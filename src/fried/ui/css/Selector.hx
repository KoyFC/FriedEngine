package fried.ui.css;

import fried.ui.UIElement;

class Compound {
	public var tag:Null<String>;
	public var id:Null<String>;
	public var classes:Array<String> = [];
	public var states:Int = 0;

	public function new() {}
}

// A chain of compound selectors, written left to right, joined by a space (any ancestor) or by a `>` (the parent).
class Selector {
	public var parts:Array<Compound>;

	// childOf[i] is true when parts[i] and parts[i + 1] are joined by a `>`.
	public var childOf:Array<Bool>;

	public var specificity:Int;

	function new(parts:Array<Compound>, childOf:Array<Bool>) {
		this.parts = parts;
		this.childOf = childOf;
		specificity = 0;
		for (part in parts) {
			if (part.id != null) {
				specificity += 10000;
			}
			specificity += (part.classes.length + countBits(part.states)) * 100;
			if (part.tag != null && part.tag != "*") {
				specificity += 1;
			}
		}
	}

	public function matches(element:UIElement):Bool {
		if (!matchesCompound(parts[parts.length - 1], element)) {
			return false;
		}
		var current = element;
		var index = parts.length - 2;
		while (index >= 0) {
			current = current.parent;
			if (childOf[index]) {
				if (current == null || !matchesCompound(parts[index], current)) {
					return false;
				}
			} else {
				while (current != null && !matchesCompound(parts[index], current)) {
					current = current.parent;
				}
				if (current == null) {
					return false;
				}
			}
			index--;
		}
		return true;
	}

	static function matchesCompound(compound:Compound, element:UIElement):Bool {
		if (compound.tag != null && compound.tag != "*" && compound.tag != element.tag) {
			return false;
		}
		if (compound.id != null && compound.id != element.id) {
			return false;
		}
		for (name in compound.classes) {
			if (!element.classList.contains(name)) {
				return false;
			}
		}
		return (element.states & compound.states) == compound.states;
	}

	// Null when the text uses something the subset leaves out, and then `problem` says what.
	public static function parse(text:String, problem:String->Void):Null<Selector> {
		var spaced = StringTools.replace(text, ">", " > ");
		var words = spaced.split(" ").filter(word -> StringTools.trim(word) != "");
		var parts:Array<Compound> = [];
		var childOf:Array<Bool> = [];
		var isChild = false;
		for (word in words) {
			if (word == ">") {
				if (parts.length == 0 || isChild) {
					problem('the combinator ">" needs a selector on each side');
					return null;
				}
				isChild = true;
				continue;
			}
			var compound = parseCompound(word, problem);
			if (compound == null) {
				return null;
			}
			if (parts.length > 0) {
				childOf.push(isChild);
			}
			isChild = false;
			parts.push(compound);
		}
		if (parts.length == 0 || isChild) {
			problem("an empty selector");
			return null;
		}
		return new Selector(parts, childOf);
	}

	static function parseCompound(word:String, problem:String->Void):Null<Compound> {
		var compound = new Compound();
		var index = 0;
		var length = word.length;
		var start = 0;
		while (index < length && isIdentifierCharacter(word.charCodeAt(index))) {
			index++;
		}
		if (index > start) {
			compound.tag = word.substr(start, index - start).toLowerCase();
		} else if (word.charAt(0) == "*") {
			compound.tag = "*";
			index = 1;
		}
		while (index < length) {
			var marker = word.charAt(index);
			if (marker != "#" && marker != "." && marker != ":") {
				problem('"$word" uses "$marker", which the subset leaves out');
				return null;
			}
			start = index + 1;
			index = start;
			while (index < length && isIdentifierCharacter(word.charCodeAt(index))) {
				index++;
			}
			var name = word.substr(start, index - start);
			if (name == "") {
				problem('"$word" has an empty name after "$marker"');
				return null;
			}
			switch (marker) {
				case "#":
					compound.id = name;
				case ".":
					compound.classes.push(name);
				case _:
					var state = ElementState.fromName(name);
					if (state == 0) {
						problem('the pseudo-class ":$name" is not supported, only :hover, :active, :focus and :disabled');
						return null;
					}
					compound.states |= state;
			}
		}
		return compound;
	}

	static function isIdentifierCharacter(code:Null<Int>):Bool {
		return code != null && (code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 97 && code <= 122 || code == 45 || code == 95);
	}

	static function countBits(value:Int):Int {
		var count = 0;
		while (value != 0) {
			count += value & 1;
			value >>= 1;
		}
		return count;
	}
}
