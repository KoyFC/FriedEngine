import fried.Time;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.graphics3d.Camera3D;
import fried.graphics3d.DirectionalLight;
import fried.graphics3d.Mesh;
import fried.graphics3d.Transform3D;
import fried.graphics3d.Vec3;
import fried.scene.Component;

class CubeField extends Component {
	public static inline var MIN_CUBES = 1;
	public static inline var MAX_CUBES = 16384;

	static inline var DISTANCE = 10.0;
	static inline var CUBE_SHARE_OF_CELL = 0.3;

	public var cubeCount(default, null):Int;
	public var trianglesDrawn(default, null):Int;

	var renderer:Renderer;
	var mesh:Mesh;
	var camera:Camera3D;
	var light:DirectionalLight;
	var cubes:Array<Transform3D>;
	var spinSpeeds:Array<Vec3>;

	public function new(renderer:Renderer, cubeCount:Int) {
		super();
		this.renderer = renderer;
		mesh = CubeMesh.create();
		camera = new Camera3D(new Rect(0, 0, renderer.width, renderer.height));
		light = new DirectionalLight(new Vec3(-0.4, -0.7, 1.0));
		cubes = [];
		spinSpeeds = [];
		trianglesDrawn = 0;
		setCubeCount(cubeCount);
	}

	public function setCubeCount(count:Int):Void {
		cubeCount = Std.int(Math.max(MIN_CUBES, Math.min(MAX_CUBES, count)));
		while (cubes.length < cubeCount) {
			var cube = new Transform3D();
			cube.rotation.x = cubes.length * 37.0;
			cube.rotation.y = cubes.length * 53.0;
			cubes.push(cube);
			spinSpeeds.push(new Vec3(30.0 + (cubes.length * 17) % 60, 40.0 + (cubes.length * 29) % 70, 0.0));
		}
		cubes.resize(cubeCount);
		spinSpeeds.resize(cubeCount);
		layOut();
	}

	function layOut():Void {
		var aspect = renderer.width / renderer.height;
		var halfHeight = DISTANCE * Math.tan(camera.fieldOfView * Math.PI / 360.0);
		var halfWidth = halfHeight * aspect;
		var columns = Math.ceil(Math.sqrt(cubeCount * aspect));
		var rows = Math.ceil(cubeCount / columns);
		var cell = Math.min(halfWidth * 2.0 / columns, halfHeight * 2.0 / rows);
		for (index in 0...cubeCount) {
			var cube = cubes[index];
			var column = index % columns;
			var row = Std.int(index / columns);
			cube.position.x = (column - (columns - 1) / 2.0) * cell;
			cube.position.y = ((rows - 1) / 2.0 - row) * cell;
			cube.position.z = DISTANCE;
			cube.scale = cell * CUBE_SHARE_OF_CELL;
		}
	}

	override function update():Void {
		for (index in 0...cubeCount) {
			var rotation = cubes[index].rotation;
			var speed = spinSpeeds[index];
			rotation.x += speed.x * Time.deltaSeconds;
			rotation.y += speed.y * Time.deltaSeconds;
		}
	}

	override function draw():Void {
		trianglesDrawn = 0;
		for (cube in cubes) {
			trianglesDrawn += camera.submitMesh(gameObject.priority, mesh, cube, light);
		}
	}
}
