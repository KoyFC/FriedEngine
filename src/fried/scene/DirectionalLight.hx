package fried.scene;

import fried.graphics3d.Rotation;

// A light that shines along its own forward from infinitely far away. A scene lights its meshes with the first one that is shown, and leaves them unlit when it has none.
@:serializable
class DirectionalLight extends Node3D {
	// How much of a mesh's color it gives out unlit, from 0 to 1.
	public var ambient:Float;

	// Where the light shines, in the world. Worked out when the node's world values are, so that a renderer that wants it each frame pays for no trigonometry.
	@:noSerialize public var directionX(get, never):Float;
	@:noSerialize public var directionY(get, never):Float;
	@:noSerialize public var directionZ(get, never):Float;

	var dx:Float;
	var dy:Float;
	var dz:Float;

	static var turn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

	public function new() {
		super();
		name = "DirectionalLight";
		ambient = 0.3;
		dx = 0.0;
		dy = 0.0;
		dz = 1.0;
	}

	// Scene keeps a list of its lights, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 128;
	}

	override function ensureWorld():Void {
		super.ensureWorld();
		Rotation.toMatrix(wrx, wry, wrz, turn);
		dx = turn[2];
		dy = turn[5];
		dz = turn[8];
	}

	inline function get_directionX():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return dx;
	}

	inline function get_directionY():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return dy;
	}

	inline function get_directionZ():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return dz;
	}
}
