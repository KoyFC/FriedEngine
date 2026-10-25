import fried.graphics.Renderer;
import fried.graphics3d.Vec3;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.SceneContext;

class Scene3D {
	var renderer:Renderer;

	public function new(renderer:Renderer) {
		this.renderer = renderer;
	}

	public function load(context:SceneContext):Void {
		var scene = context.pushScene(renderer, new Scene("Sandbox 3D"));
		var size = Std.int(Math.min(renderer.width, renderer.height) * 0.6);
		var cubeObject = scene.add(new GameObject("Spinning cube", (renderer.width - size) / 2, (renderer.height - size) / 2));
		cubeObject.addComponent(new SpinningCube(size, new Vec3(35.0, 50.0, 0.0)));
	}
}
