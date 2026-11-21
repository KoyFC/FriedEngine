package scene3d;

import nodes.CubeField;
import debug.DebugOverlay;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.input.InputAction;
import fried.input.Key;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.Label;

class Scene3D {
	var renderer:Renderer;
	var font:Font;
	var overlay:DebugOverlay;

	public function new(renderer:Renderer, font:Font, overlay:DebugOverlay) {
		this.renderer = renderer;
		this.font = font;
		this.overlay = overlay;
	}

	// What the game adds to the 3D scene once it is loaded: the keys that change the number of cubes and what the overlay shows.
	public function wire(context:SceneContext, scene:Scene):Void {
		var field = scene.getById("cube-field", CubeField);
		scene.getById("hint", Label).font = font;

		function doubleCubes():Void {
			field.setCubeCount(field.cubeCount * 2);
		}
		function halveCubes():Void {
			field.setCubeCount(Std.int(field.cubeCount / 2));
		}

		var more = new InputAction("More cubes", Button).addKey(Key.Up);
		more.onPressed = doubleCubes;
		more.enable();
		var fewer = new InputAction("Fewer cubes", Button).addKey(Key.Down);
		fewer.onPressed = halveCubes;
		fewer.enable();
		context.onUnload(function() {
			more.disable();
			fewer.disable();
		});

		overlay.setSceneDetails(context, () -> ['cubes ${field.cubeCount}', 'triangles ${scene.camera3D.trianglesDrawn}']);
		overlay.addSceneButton(context, () -> "Cubes x2", doubleCubes);
		overlay.addSceneButton(context, () -> "Cubes /2", halveCubes);
	}
}
