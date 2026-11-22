package fried.input;

import fried.input.InputMapParser.InputTables;

// The names project.fried and the editor use for keys, buttons and axes: the names of the values of the enums they come from, such as `W`, `LeftShift`, `South` or `LeftX`.
class InputNames {
	public static final tables:InputTables = {
		keys: InputNamesMacro.table(fried.input.Key),
		mouseButtons: InputNamesMacro.table(fried.input.MouseButton),
		gamepadButtons: InputNamesMacro.table(fried.input.GamepadButton),
		gamepadAxes: InputNamesMacro.table(fried.input.GamepadAxis)
	};

	// The four tables as the editor reads them, each a list of `{name, code}` in the order of the enum.
	public static function describe():Dynamic {
		return {
			keys: list(tables.keys),
			mouseButtons: list(tables.mouseButtons),
			gamepadButtons: list(tables.gamepadButtons),
			gamepadAxes: list(tables.gamepadAxes)
		};
	}

	static function list(table:Map<String, Int>):Array<Dynamic> {
		var entries:Array<Dynamic> = [for (name => code in table) {name: name, code: code}];
		entries.sort(function(a, b) return a.code != b.code ? a.code - b.code : (a.name < b.name ? -1 : 1));
		return entries;
	}
}
