import fried.graphics.Color;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.input.GamepadButton;
import fried.input.InputAction;
import fried.input.Key;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.Text;

class Scene3D {
	static inline var STARTING_CUBES = 16;

	var renderer:Renderer;
	var font:Font;
	var overlay:DebugOverlay;

	public function new(renderer:Renderer, font:Font, overlay:DebugOverlay) {
		this.renderer = renderer;
		this.font = font;
		this.overlay = overlay;
	}

	public function load(context:SceneContext):Void {
		var scene = context.pushScene(renderer, new Scene("Sandbox 3D"));
		var field = scene.add(new GameObject("Cube field")).addComponent(new CubeField(renderer, STARTING_CUBES));

		var hintObject = scene.add(new GameObject("Hint", 12, 12));
		hintObject.priority = 1;
		hintObject.addComponent(new Text(font, "Up/Down: cubes x2 or /2   F2/North: next scene", Color.rgb(220, 220, 230)));

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
