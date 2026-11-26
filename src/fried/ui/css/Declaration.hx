package fried.ui.css;

// One property of a rule with its value parsed. A shorthand has already been spread into its longhands.
class Declaration {
	public var property:Int;
	public var value:StyleValue;

	public function new(property:Int, value:StyleValue) {
		this.property = property;
		this.value = value;
	}
}
