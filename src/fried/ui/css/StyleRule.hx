package fried.ui.css;

// A selector with the declarations it applies. A list of selectors in the file is one rule for each.
class StyleRule {
	public var selector:Selector;
	public var declarations:Array<Declaration>;

	// Where the rule stands in its sheet, which breaks a tie of specificity.
	public var order:Int;

	public function new(selector:Selector, declarations:Array<Declaration>, order:Int) {
		this.selector = selector;
		this.declarations = declarations;
		this.order = order;
	}
}
