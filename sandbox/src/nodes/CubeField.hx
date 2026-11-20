package nodes;

import fried.graphics3d.Mesh;
import fried.scene.MeshInstance;
import fried.scene.Node3D;
import scene3d.CubeMesh;

// A field of spinning cubes in front of the scene's 3D camera, laid out at the size of the scene's view so the editor shows it too. It sits where the camera looks, DISTANCE away from it.
@:serializable
class CubeField extends Node3D {
	public static inline var MIN_CUBES = 1;
	public static inline var MAX_CUBES = 16384;

	static inline var DISTANCE = 10.0;
	static inline var CUBE_SHARE_OF_CELL = 0.3;

	public var cubeCount(default, set):Int;

	var viewWidth:Int;
	var viewHeight:Int;
	var fieldOfView:Float;
	var mesh:Mesh;
	var cubes:Array<MeshInstance>;
	var spinSpeedsX:Array<Float>;
	var spinSpeedsY:Array<Float>;

	public function new(cubeCount:Int = 16) {
		super();
		name = "CubeField";
		z = DISTANCE;
		viewWidth = 0;
		viewHeight = 0;
		fieldOfView = 60.0;
		mesh = CubeMesh.create();
		cubes = [];
		spinSpeedsX = [];
		spinSpeedsY = [];
		this.cubeCount = cubeCount;
	}

	public function setCubeCount(count:Int):Void {
		cubeCount = count;
	}

	function set_cubeCount(count:Int):Int {
		cubeCount = Std.int(Math.max(MIN_CUBES, Math.min(MAX_CUBES, count)));
		while (cubes.length < cubeCount) {
			var cube = new MeshInstance();
			cube.mesh = mesh;
			cube.rotationX = cubes.length * 37.0;
			cube.rotationY = cubes.length * 53.0;
			addChild(cube);
			cubes.push(cube);
			spinSpeedsX.push(30.0 + (cubes.length * 17) % 60);
			spinSpeedsY.push(40.0 + (cubes.length * 29) % 70);
		}
		while (cubes.length > cubeCount) {
			cubes.pop().destroy();
			spinSpeedsX.pop();
			spinSpeedsY.pop();
		}
		layOut();
		return cubeCount;
	}

	function followView():Void {
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
		for (index in 0...cubeCount) {
			var cube = cubes[index];
			cube.rotationX += spinSpeedsX[index] * delta;
			cube.rotationY += spinSpeedsY[index] * delta;
		}
	}

	override function draw():Void {
		followView();
	}
}
