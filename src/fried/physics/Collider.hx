package fried.physics;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.scene.Node2D;

// An axis aligned box that Physics finds. A body is stopped by the solid colliders whose layer its mask names, and a trigger is one that stops nothing and is only reported, so a zone or a shot can notice what it touches. Its position is the box's top left corner, in its parent's space, so what used to be a collider's offset is where the node sits, and it follows a node it is a child of.
@:serializable
@:allow(fried.physics)
class Collider extends Node2D {
	public var width(default, set):Float;
	public var height(default, set):Float;

	// The layers this collider is on, and the layers a body made of it is stopped by or told about. One bit each, and every collider starts on the first and sees the first.
	public var collisionLayer:Int;
	public var collisionMask:Int;
	public var isTrigger:Bool;

	public var isDebugVisible:Bool;
	public var debugColor:Color;

	@:noSerialize public var left(get, never):Float;
	@:noSerialize public var top(get, never):Float;
	@:noSerialize public var right(get, never):Float;
	@:noSerialize public var bottom(get, never):Float;
	@:noSerialize public var centerX(get, never):Float;
	@:noSerialize public var centerY(get, never):Float;

	var debugRect:Rect;

	// The box in world space, worked out when read and again only after the node, an ancestor or the size changed. The DS has no hardware floating point, so a query reads these and does not multiply again for every candidate.
	var boundsLeft:Float;
	var boundsTop:Float;
	var boundsRight:Float;
	var boundsBottom:Float;
	var boundsDirty:Bool;

	public function new(width:Float = 0.0, height:Float = 0.0) {
		super();
		name = "Collider";
		this.width = width;
		this.height = height;
		collisionLayer = 1;
		collisionMask = 1;
		isTrigger = false;
		isDebugVisible = false;
		debugColor = Color.rgb(90, 230, 130);
		boundsDirty = true;
	}

	// It draws, for the debug outline, and Scene keeps a list of colliders for Physics, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 2 | 8;
	}

	override function markWorldDirty():Void {
		boundsDirty = true;
		super.markWorldDirty();
	}

	function refreshBounds():Void {
		var sizeX = width * worldScaleX;
		var sizeY = height * worldScaleY;
		var originX = worldX;
		var originY = worldY;
		if (sizeX < 0.0) {
			boundsLeft = originX + sizeX;
			boundsRight = originX;
		} else {
			boundsLeft = originX;
			boundsRight = originX + sizeX;
		}
		if (sizeY < 0.0) {
			boundsTop = originY + sizeY;
			boundsBottom = originY;
		} else {
			boundsTop = originY;
			boundsBottom = originY + sizeY;
		}
		boundsDirty = false;
	}

	public function overlaps(other:Collider):Bool {
		if (other == null || other == this) {
			return false;
		}
		if (boundsDirty) {
			refreshBounds();
		}
		if (other.boundsDirty) {
			other.refreshBounds();
		}
		return boundsLeft < other.boundsRight && boundsRight > other.boundsLeft && boundsTop < other.boundsBottom && boundsBottom > other.boundsTop;
	}

	public function overlapsBox(x:Float, y:Float, width:Float, height:Float):Bool {
		var boxLeft = width < 0.0 ? x + width : x;
		var boxRight = width < 0.0 ? x : x + width;
		var boxTop = height < 0.0 ? y + height : y;
		var boxBottom = height < 0.0 ? y : y + height;
		if (boundsDirty) {
			refreshBounds();
		}
		return boundsLeft < boxRight && boundsRight > boxLeft && boundsTop < boxBottom && boundsBottom > boxTop;
	}

	public function containsPoint(x:Float, y:Float):Bool {
		if (boundsDirty) {
			refreshBounds();
		}
		return x >= boundsLeft && x < boundsRight && y >= boundsTop && y < boundsBottom;
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

	function set_width(value:Float):Float {
		width = value;
		boundsDirty = true;
		return value;
	}

	function set_height(value:Float):Float {
		height = value;
		boundsDirty = true;
		return value;
	}

	function get_left():Float {
		if (boundsDirty) {
			refreshBounds();
		}
		return boundsLeft;
	}

	function get_right():Float {
		if (boundsDirty) {
			refreshBounds();
		}
		return boundsRight;
	}

	function get_top():Float {
		if (boundsDirty) {
			refreshBounds();
		}
		return boundsTop;
	}

	function get_bottom():Float {
		if (boundsDirty) {
			refreshBounds();
		}
		return boundsBottom;
	}

	function get_centerX():Float {
		return worldX + width * worldScaleX / 2.0;
	}

	function get_centerY():Float {
		return worldY + height * worldScaleY / 2.0;
	}
}
