package fried.nodes.physics;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;

// An axis aligned box that Physics finds. Its position is the box's top left corner, in its parent's space, so what used to be a collider's offset is where the node sits, and it follows a node it is a child of.
@:serializable
class Collider extends Node2D {
	public var width:Float;
	public var height:Float;

	public var isDebugVisible:Bool;
	public var debugColor:Color;

	@:noSerialize public var left(get, never):Float;
	@:noSerialize public var top(get, never):Float;
	@:noSerialize public var right(get, never):Float;
	@:noSerialize public var bottom(get, never):Float;
	@:noSerialize public var centerX(get, never):Float;
	@:noSerialize public var centerY(get, never):Float;

	var debugRect:Rect;

	public function new(width:Float = 0.0, height:Float = 0.0) {
		super();
		name = "Collider";
		this.width = width;
		this.height = height;
		isDebugVisible = false;
		debugColor = Color.rgb(90, 230, 130);
	}

	// It draws, for the debug outline, and Scene keeps a list of colliders for Physics, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 2 | 8;
	}

	public function overlaps(other:Collider):Bool {
		if (other == null || other == this) {
			return false;
		}
		return left < other.right && right > other.left && top < other.bottom && bottom > other.top;
	}

	public function overlapsBox(x:Float, y:Float, width:Float, height:Float):Bool {
		var boxLeft = width < 0.0 ? x + width : x;
		var boxRight = width < 0.0 ? x : x + width;
		var boxTop = height < 0.0 ? y + height : y;
		var boxBottom = height < 0.0 ? y : y + height;
		return left < boxRight && right > boxLeft && top < boxBottom && bottom > boxTop;
	}

	public function containsPoint(x:Float, y:Float):Bool {
		return x >= left && x < right && y >= top && y < bottom;
	}

	override function draw():Void {
		if (!isDebugVisible) {
			return;
		}
		if (debugRect == null) {
			debugRect = new Rect(0, 0, 0, 0);
		}
		debugRect.x = Std.int(left);
		debugRect.y = Std.int(top);
		debugRect.width = Std.int(right) - debugRect.x;
		debugRect.height = Std.int(bottom) - debugRect.y;
		DrawQueue.submitRect(priority, debugRect, debugColor);
	}

	override function destroyed():Void {
		debugRect = null;
	}

	function get_left():Float {
		var size = width * worldScaleX;
		return size < 0.0 ? worldX + size : worldX;
	}

	function get_right():Float {
		var size = width * worldScaleX;
		return size < 0.0 ? worldX : worldX + size;
	}

	function get_top():Float {
		var size = height * worldScaleY;
		return size < 0.0 ? worldY + size : worldY;
	}

	function get_bottom():Float {
		var size = height * worldScaleY;
		return size < 0.0 ? worldY : worldY + size;
	}

	function get_centerX():Float {
		return worldX + width * worldScaleX / 2.0;
	}

	function get_centerY():Float {
		return worldY + height * worldScaleY / 2.0;
	}
}
