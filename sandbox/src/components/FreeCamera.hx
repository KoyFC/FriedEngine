package components;

import fried.Time;
import fried.input.GamepadAxis;
import fried.input.Input;
import fried.input.GamepadButton;
import fried.input.Key;
import fried.input.MouseButton;
import fried.scene.Component;
import fried.scene.Transform3D;

// Flies the Transform3D it is on, or below. Turning is J and L, the right stick, the pointer with the right mouse button held, or the face buttons (West and East turn, North and South tilt), which are what a console without a second stick has. I and K tilt, and W, S, A and D or the left stick move it along where it looks and across.
@:serializable
class FreeCamera extends Component {
	static inline var TURN_SPEED = 60.0;
	static inline var MOVE_SPEED = 5.0;
	static inline var DEADZONE = 0.2;
	static inline var MAX_TILT = 89.0;
	static inline var DEGREES_PER_PIXEL = 0.3;

	var target:Null<Transform3D>;
	var isLooking:Bool;
	var lastPointerX:Int;
	var lastPointerY:Int;

	public function new() {
		super();
		isLooking = false;
		lastPointerX = 0;
		lastPointerY = 0;
	}

	override function start():Void {
		target = gameObject.getComponentInParent(Transform3D);
	}

	override function update(delta:Float):Void {
		if (target == null) {
			return;
		}
		var turn = axis(Key.L, Key.J, GamepadAxis.RightX, 1.0) + buttons(GamepadButton.East, GamepadButton.West);
		var tilt = axis(Key.K, Key.I, GamepadAxis.RightY, 1.0) + buttons(GamepadButton.South, GamepadButton.North);
		turn = Math.max(-1.0, Math.min(1.0, turn));
		tilt = Math.max(-1.0, Math.min(1.0, tilt));

		// The pointer turns the camera by how far it moved while the right button was held, so a press does not jump.
		var pointerX = Input.mouseX;
		var pointerY = Input.mouseY;
		var pointerTurn = 0.0;
		var pointerTilt = 0.0;
		if (Input.isButtonPressed(MouseButton.Right)) {
			if (isLooking) {
				pointerTurn = (pointerX - lastPointerX) * DEGREES_PER_PIXEL;
				pointerTilt = (pointerY - lastPointerY) * DEGREES_PER_PIXEL;
			}
			isLooking = true;
		} else {
			isLooking = false;
		}
		lastPointerX = pointerX;
		lastPointerY = pointerY;

		var forward = clampUnit(axis(Key.W, Key.S, GamepadAxis.LeftY, -1.0) + buttons(GamepadButton.DpadUp, GamepadButton.DpadDown));
		var across = clampUnit(axis(Key.D, Key.A, GamepadAxis.LeftX, 1.0) + buttons(GamepadButton.DpadRight, GamepadButton.DpadLeft));

		target.rotationY += turn * TURN_SPEED * delta + pointerTurn;
		target.rotationX = Math.max(-MAX_TILT, Math.min(MAX_TILT, target.rotationX + tilt * TURN_SPEED * delta + pointerTilt));

		var yaw = target.rotationY * Math.PI / 180.0;
		var pitch = target.rotationX * Math.PI / 180.0;
		var step = MOVE_SPEED * delta;
		target.x += (Math.sin(yaw) * Math.cos(pitch) * forward + Math.cos(yaw) * across) * step;
		target.y += -Math.sin(pitch) * forward * step;
		target.z += (Math.cos(yaw) * Math.cos(pitch) * forward - Math.sin(yaw) * across) * step;
	}

	function clampUnit(value:Float):Float {
		return Math.max(-1.0, Math.min(1.0, value));
	}

	function buttons(positive:GamepadButton, negative:GamepadButton):Float {
		return (Input.isGamepadButtonPressed(positive) ? 1.0 : 0.0) - (Input.isGamepadButtonPressed(negative) ? 1.0 : 0.0);
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
