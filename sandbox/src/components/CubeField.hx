package components;

import fried.graphics3d.Mesh;
import fried.scene.Component;
import fried.scene.GameObject;
import fried.scene.MeshRenderer;
import fried.scene.Transform3D;
import scene3d.CubeMesh;

// A field of spinning cubes in front of the scene's 3D camera, laid out at the size of the scene's view so the editor shows it too. It sits where the camera looks, DISTANCE away from it.
@:serializable
class CubeField extends Component {
	public static inline var MIN_CUBES = 1;
	public static inline var MAX_CUBES = 16384;

	static inline var DISTANCE = 10.0;
	static inline var CUBE_SHARE_OF_CELL = 0.3;

	public var cubeCount(default, set):Int;

	// How long the cubes have spun, in seconds. Their turn is worked out from it, so a scene that is shown this value shows the cubes where the running game has them.
	public var age(default, set):Float;

	var viewWidth:Int;
	var viewHeight:Int;
	var fieldOfView:Float;
	var mesh:Mesh;
	var place:Transform3D;
	var cubes:Array<Transform3D>;
	var spinSpeedsX:Array<Float>;
	var spinSpeedsY:Array<Float>;

	public function new(cubeCount:Int = 16) {
		super();
		viewWidth = 0;
		viewHeight = 0;
		fieldOfView = 60.0;
		mesh = CubeMesh.create();
		cubes = [];
		spinSpeedsX = [];
		spinSpeedsY = [];
		age = 0.0;
		this.cubeCount = cubeCount;
	}

	public function setCubeCount(count:Int):Void {
		cubeCount = count;
	}

	override function awake():Void {
		place = need(Transform3D);
		build();
	}

	function set_cubeCount(count:Int):Int {
		cubeCount = Std.int(Math.max(MIN_CUBES, Math.min(MAX_CUBES, count)));
		if (place != null) {
			build();
		}
		return cubeCount;
	}

	function build():Void {
		while (cubes.length < cubeCount) {
			var object = new GameObject("Cube", new Transform3D());
			var renderer = object.addComponent(new MeshRenderer());
			renderer.mesh = mesh;
			object.transform.setParent(place);
			cubes.push(cast object.transform);
			spinSpeedsX.push(30.0 + (cubes.length * 17) % 60);
			spinSpeedsY.push(40.0 + (cubes.length * 29) % 70);
		}
		while (cubes.length > cubeCount) {
			cubes.pop().gameObject.destroy();
			spinSpeedsX.pop();
			spinSpeedsY.pop();
		}
		layOut();
		spin();
	}

	function set_age(seconds:Float):Float {
		age = seconds;
		spin();
		return age;
	}

	function spin():Void {
		for (index in 0...cubes.length) {
			cubes[index].rotationX = index * 37.0 + spinSpeedsX[index] * age;
			cubes[index].rotationY = index * 53.0 + spinSpeedsY[index] * age;
		}
	}

	function followView():Void {
		if (place == null) {
			return;
		}
		var scene = gameObject.scene;
		var camera = scene.camera3D;
		var fieldOfViewNow = camera != null ? camera.fieldOfView : 60.0;
		if (scene.viewWidth != viewWidth || scene.viewHeight != viewHeight || fieldOfViewNow != fieldOfView) {
			viewWidth = scene.viewWidth;
			viewHeight = scene.viewHeight;
			fieldOfView = fieldOfViewNow;
			layOut();
		}
	}

	function layOut():Void {
		if (viewWidth == 0 || viewHeight == 0) {
			return;
		}
		var aspect = viewWidth / viewHeight;
		var halfHeight = DISTANCE * Math.tan(fieldOfView * Math.PI / 360.0);
		var halfWidth = halfHeight * aspect;
		var columns = Math.ceil(Math.sqrt(cubeCount * aspect));
		var rows = Math.ceil(cubeCount / columns);
		var cell = Math.min(halfWidth * 2.0 / columns, halfHeight * 2.0 / rows);
		for (index in 0...cubeCount) {
			var cube = cubes[index];
			var column = index % columns;
			var row = Std.int(index / columns);
			cube.x = (column - (columns - 1) / 2.0) * cell;
			cube.y = ((rows - 1) / 2.0 - row) * cell;
			cube.setScale(cell * CUBE_SHARE_OF_CELL);
		}
	}

	override function update(delta:Float):Void {
		followView();
		age += delta;
	}

	override function draw():Void {
		followView();
	}
}
