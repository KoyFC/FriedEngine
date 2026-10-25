import fried.Time;
import fried.graphics.Color;
import fried.graphics.Rect;
import fried.graphics3d.Camera3D;
import fried.graphics3d.DirectionalLight;
import fried.graphics3d.Mesh;
import fried.graphics3d.Transform3D;
import fried.graphics3d.Vec3;
import fried.scene.Component;

// Drawn into a square of the given size whose top left corner follows the game object.
class SpinningCube extends Component {
	static inline var DISTANCE = 4.0;

	var mesh:Mesh;
	var model:Transform3D;
	var camera:Camera3D;
	var light:DirectionalLight;
	var degreesPerSecond:Vec3;

	public function new(size:Int, degreesPerSecond:Vec3) {
		super();
		mesh = cubeMesh();
		model = new Transform3D(0.0, 0.0, DISTANCE);
		camera = new Camera3D(new Rect(0, 0, size, size));
		light = new DirectionalLight(new Vec3(-0.4, -0.7, 1.0));
		this.degreesPerSecond = degreesPerSecond;
	}

	override function update():Void {
		model.rotation.x += degreesPerSecond.x * Time.deltaSeconds;
		model.rotation.y += degreesPerSecond.y * Time.deltaSeconds;
		model.rotation.z += degreesPerSecond.z * Time.deltaSeconds;
	}

	override function draw():Void {
		camera.viewport.x = Std.int(transform.x);
		camera.viewport.y = Std.int(transform.y);
		camera.submitMesh(gameObject.priority, mesh, model, light);
	}

	// Corner i is at -1 or +1 on x, y and z by its bits 0, 1 and 2, and each
	// face is two triangles in one colour.
	static function cubeMesh():Mesh {
		var vertices = [];
		for (corner in 0...8) {
			vertices.push((corner & 1) != 0 ? 1.0 : -1.0);
			vertices.push((corner & 2) != 0 ? 1.0 : -1.0);
			vertices.push((corner & 4) != 0 ? 1.0 : -1.0);
		}
		var indices = [
			2, 3, 1, 2, 1, 0, // -z
			7, 6, 4, 7, 4, 5, // +z
			6, 2, 0, 6, 0, 4, // -x
			3, 7, 5, 3, 5, 1, // +x
			6, 7, 3, 6, 3, 2, // +y
			0, 1, 5, 0, 5, 4 // -y
		];
		var faceColors = [
			Color.rgb(255, 140, 40),
			Color.rgb(90, 200, 140),
			Color.rgb(80, 150, 255),
			Color.rgb(230, 80, 90),
			Color.rgb(240, 220, 90),
			Color.rgb(170, 110, 230)
		];
		var colors = [];
		for (color in faceColors) {
			colors.push(color);
			colors.push(color);
		}
		return new Mesh(vertices, indices, colors);
	}
}
