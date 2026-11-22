package nodes;

import fried.input.InputAction;
import fried.input.Key;
import fried.scene.Label;
import fried.scene.Node;

// What the 3D scene needs from code on top of its file: the keys that change the number of cubes and what the debug overlay shows while it is on screen.
@:serializable
class CubeControls extends Node {
	public var field:CubeField;
	public var hint:Label;

	var more:InputAction;
	var fewer:InputAction;
	var overlay:debug.DebugOverlay;

	override function ready():Void {
		var shell = SandboxShell.of();
		overlay = shell.overlay;
		hint.font = shell.font;

		function doubleCubes():Void {
			field.setCubeCount(field.cubeCount * 2);
		}
		function halveCubes():Void {
			field.setCubeCount(Std.int(field.cubeCount / 2));
		}

		more = new InputAction("More cubes", Button).addKey(Key.Up);
		more.onPressed = doubleCubes;
		more.enable();
		fewer = new InputAction("Fewer cubes", Button).addKey(Key.Down);
		fewer.onPressed = halveCubes;
		fewer.enable();

		overlay.setSceneDetails(this, () -> ['cubes ${field.cubeCount}', 'triangles ${scene.camera3D.trianglesDrawn}']);
		overlay.addSceneButton(this, () -> "Cubes x2", doubleCubes);
		overlay.addSceneButton(this, () -> "Cubes /2", halveCubes);
	}

	override function destroyed():Void {
		// A scene the editor only looks at is never readied.
		if (overlay == null) {
			return;
		}
		more.disable();
		fewer.disable();
		overlay.removeOwner(this);
	}
}
