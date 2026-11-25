package fried.scene;

import fried.input.Input;

// Which platforms an on-screen control is shown on, written as the platform keys of project.fried separated by spaces or commas, such as "android web". The word "auto" stands for where a finger touches the screen the game is drawn on, and an empty list is just that.
class PlatformList {
	// The editor's view of a scene shows every control, so each can be placed.
	public static var isEditing:Bool = false;
	// The platform a game started by the editor pretends to be, to see what each platform gets. Empty is the real one.
	public static var previewed:String = "";

	public static function shows(list:String):Bool {
		if (isEditing) {
			return true;
		}
		var platform = previewed == "" ? Application.platformName : previewed;
		var isAuto = previewed == "" ? Input.isTouchOnDisplay : touchesDisplay(platform);
		if (list == null || StringTools.trim(list) == "") {
			return isAuto;
		}
		for (entry in ~/[\s,]+/g.split(list.toLowerCase())) {
			if (entry == platform || (entry == "auto" && isAuto)) {
				return true;
			}
		}
		return false;
	}

	// What Input.isTouchOnDisplay is on each platform, for the ones a computer only pretends to be.
	static function touchesDisplay(platform:String):Bool {
		return platform != "nds" && platform != "3ds" && platform != "cg50";
	}
}
