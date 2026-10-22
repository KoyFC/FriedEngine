package fried.input;

// Actions that are enabled and disabled together.
class InputActionMap {
	public var name(default, null):String;
	public var actions(default, null):Array<InputAction> = [];

	public function new(name:String) {
		this.name = name;
	}

	public function addAction(name:String, type:InputActionType):InputAction {
		var action = new InputAction(name, type);
		actions.push(action);
		return action;
	}

	public function getAction(name:String):InputAction {
		for (action in actions) {
			if (action.name == name) {
				return action;
			}
		}
		return null;
	}

	public function enable():Void {
		for (action in actions) {
			action.enable();
		}
	}

	public function disable():Void {
		for (action in actions) {
			action.disable();
		}
	}
}
