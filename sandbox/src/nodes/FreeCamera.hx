package nodes;

import fried.Time;
import fried.input.GamepadAxis;
import fried.input.Input;
import fried.input.Key;
import fried.scene.Camera3D;
import fried.scene.Node;

// Flies the Camera3D it is a child of: J and L or the right stick turn it, I and K tilt it, and W, S, A and D or the left stick move it along where it looks and across.
@:serializable
class FreeCamera extends Node {
	static inline var TURN_SPEED = 60.0;
	static inline var MOVE_SPEED = 5.0;
	static inline var DEADZONE = 0.2;
	static inline var MAX_TILT = 89.0;

	var target:Null<Camera3D>;

	public function new() {
		super("FreeCamera");
	}

	override function ready():Void {
		target = findParent(Camera3D);
	}

	override function update(delta:Float):Void {
		if (target == null) {
			return;
		}
		var turn = axis(Key.L, Key.J, GamepadAxis.RightX, 1.0);
		var tilt = axis(Key.K, Key.I, GamepadAxis.RightY, 1.0);
		var forward = axis(Key.W, Key.S, GamepadAxis.LeftY, -1.0);
		var across = axis(Key.D, Key.A, GamepadAxis.LeftX, 1.0);

		target.rotationY += turn * TURN_SPEED * delta;
		target.rotationX = Math.max(-MAX_TILT, Math.min(MAX_TILT, target.rotationX + tilt * TURN_SPEED * delta));

		var yaw = target.rotationY * Math.PI / 180.0;
		var pitch = target.rotationX * Math.PI / 180.0;
		var step = MOVE_SPEED * delta;
		target.x += (Math.sin(yaw) * Math.cos(pitch) * forward + Math.cos(yaw) * across) * step;
		target.y += -Math.sin(pitch) * forward * step;
		target.z += (Math.cos(yaw) * Math.cos(pitch) * forward - Math.sin(yaw) * across) * step;
	}

	// A key pair or a stick as a number from -1 to 1.
	function axis(positive:Key, negative:Key, stick:GamepadAxis, stickSign:Float):Float {
		var value = (Input.isKeyPressed(positive) ? 1.0 : 0.0) - (Input.isKeyPressed(negative) ? 1.0 : 0.0);
		var pad = Input.getGamepadAxis(stick) * stickSign;
		if (Math.abs(pad) > DEADZONE) {
			value += pad;
		}
		return Math.max(-1.0, Math.min(1.0, value));
	}
}
