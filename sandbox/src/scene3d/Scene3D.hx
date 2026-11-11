package scene3d;

import components.CubeField;
import debug.DebugOverlay;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.input.GamepadButton;
import fried.input.InputAction;
import fried.input.Key;
import fried.scene.SceneContext;
import fried.scene.Text;
import fried.scene.serialization.SceneLoader;

class Scene3D {
	var renderer:Renderer;
	var font:Font;
	var overlay:DebugOverlay;

	public function new(renderer:Renderer, font:Font, overlay:DebugOverlay) {
		this.renderer = renderer;
		this.font = font;
		this.overlay = overlay;
	}

	public function load(context:SceneContext):Void {
		var scene = context.pushScene(renderer, SceneLoader.load("scenes/sandbox_3d.scene.json", renderer));
		var field = scene.findById("cube-field").getComponent(CubeField);
		scene.findById("hint").getComponent(Text).font = font;

		function doubleCubes():Void {
			field.setCubeCount(field.cubeCount * 2);
		}
		function halveCubes():Void {
			field.setCubeCount(Std.int(field.cubeCount / 2));
		}

		var more = new InputAction("More cubes", Button).addKey(Key.Up).addGamepadButton(GamepadButton.DpadUp);
		more.onPressed = doubleCubes;
		more.enable();
		var fewer = new InputAction("Fewer cubes", Button).addKey(Key.Down).addGamepadButton(GamepadButton.DpadDown);
		fewer.onPressed = halveCubes;
		fewer.enable();
		context.onUnload(function() {
			more.disable();
			fewer.disable();
		});

		overlay.setSceneDetails(context, () -> ['cubes ${field.cubeCount}', 'triangles ${field.trianglesDrawn}']);
		overlay.addSceneButton(context, () -> "Cubes x2", doubleCubes);
		overlay.addSceneButton(context, () -> "Cubes /2", halveCubes);
	}
}
