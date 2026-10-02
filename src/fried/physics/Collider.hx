package fried.physics;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.scene.Component;

class Collider extends Component {
	public var width:Float;
	public var height:Float;
	public var offsetX:Float;
	public var offsetY:Float;

	public var isDebugVisible:Bool;
	public var debugColor:Color;

	public var left(get, never):Float;
	public var top(get, never):Float;
	public var right(get, never):Float;
	public var bottom(get, never):Float;
	public var centerX(get, never):Float;
	public var centerY(get, never):Float;

	var debugRect:Rect;

	public function new(width:Float, height:Float, offsetX:Float = 0.0, offsetY:Float = 0.0) {
		super();
		this.width = width;
		this.height = height;
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		isDebugVisible = false;
		debugColor = Color.rgb(90, 230, 130);
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
		DrawQueue.submitRect(gameObject.priority, debugRect, debugColor);
	}

	override function destroy():Void {
		debugRect = null;
	}

	function get_left():Float {
		var edge = transform.x + offsetX * transform.scaleX;
		var size = width * transform.scaleX;
		return size < 0.0 ? edge + size : edge;
	}

	function get_right():Float {
		var edge = transform.x + offsetX * transform.scaleX;
		var size = width * transform.scaleX;
		return size < 0.0 ? edge : edge + size;
	}

	function get_top():Float {
		var edge = transform.y + offsetY * transform.scaleY;
		var size = height * transform.scaleY;
		return size < 0.0 ? edge + size : edge;
	}

	function get_bottom():Float {
		var edge = transform.y + offsetY * transform.scaleY;
		var size = height * transform.scaleY;
		return size < 0.0 ? edge : edge + size;
	}

	function get_centerX():Float {
		return transform.x + (offsetX + width / 2.0) * transform.scaleX;
	}

	function get_centerY():Float {
		return transform.y + (offsetY + height / 2.0) * transform.scaleY;
	}
}
