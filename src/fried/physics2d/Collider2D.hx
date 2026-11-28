package fried.physics2d;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.scene.Renderer2D;
import fried.scene.Transform2D;
import fried.scene.TransformStore2D;

// An axis aligned box that Physics2D finds. A body is stopped by the solid colliders whose layer its mask names, and a trigger is one that stops nothing and is only reported, so a zone or a shot can notice what it touches. Its position is the box's top left corner, the position of its object, which it follows.
@:serializable
@:allow(fried.physics2d)
@:allow(fried.scene)
class Collider2D extends Renderer2D {
	public var width(default, set):Single;
	public var height(default, set):Single;

	// The layers this collider is on, and the layers a body made of it is stopped by or told about. One bit each, and every collider starts on the first and sees the first.
	public var collisionLayer:Int;
	public var collisionMask:Int;
	public var isTrigger:Bool;

	public var isDebugVisible:Bool;
	public var debugColor:Color;

	@:noSerialize public var left(get, never):Single;
	@:noSerialize public var top(get, never):Single;
	@:noSerialize public var right(get, never):Single;
	@:noSerialize public var bottom(get, never):Single;
	@:noSerialize public var centerX(get, never):Single;
	@:noSerialize public var centerY(get, never):Single;

	var debugRect:Rect;
	var place:Transform2D;

	static var boundsValues:Array<Int> = [0, 0, 0, 0];

	// The box in world space as integers, in 20.12 (see FixedPoint), worked out when read and again only after the node, an ancestor or the size changed. A query compares these and does no arithmetic on a Single for every candidate, which is a call into software floating point on the DS.
	var boundsLeft:Int;
	var boundsTop:Int;
	var boundsRight:Int;
	var boundsBottom:Int;
	var boundsDirty:Bool;

	static inline var ZERO:Single = 0.0;
	static inline var ONE:Single = 1.0;
	static inline var HALF:Single = 0.5;

	// The same box as Singles, for what asks for left, right, top and bottom, which is worked out only when one of them is read.
	var exactLeft:Single;
	var exactTop:Single;
	var exactRight:Single;
	var exactBottom:Single;
	var exactDirty:Bool;

	// Where the scene's grid has it: its place in tree order, and whether it is queued because its box has changed and the grid has not been told.
	var order:Int;
	var isQueued:Bool;

	public function new(width:Single = 0.0, height:Single = 0.0) {
		super();
		this.width = width;
		this.height = height;
		collisionLayer = 1;
		collisionMask = 1;
		isTrigger = false;
		isDebugVisible = false;
		debugColor = Color.rgb(90, 230, 130);
		boundsDirty = true;
		exactDirty = true;
		order = 0;
		isQueued = false;
	}

	// It draws, for the debug outline, and Scene keeps a list of colliders for Physics2D, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 2 | 8;
	}

	override function awake():Void {
		place = need(Transform2D);
		place.collider = this;
	}

	function moved():Void {
		boundsDirty = true;
		exactDirty = true;
		queueForGrid();
	}

	function queueForGrid():Void {
		if (!isQueued && gameObject != null && gameObject.scene != null) {
			gameObject.scene.colliderMoved(this);
		}
	}

	function refreshBounds():Void {
		if (place.slot >= 0) {
			place.ensureSlot();
			var values = boundsValues;
			TransformStore2D.bounds(place.slot, width, height, cpp.Pointer.ofArray(values).raw);
			boundsLeft = values[0];
			boundsTop = values[1];
			boundsRight = values[2];
			boundsBottom = values[3];
			boundsDirty = false;
			return;
		}
		var scaleX = place.worldScaleX;
		var scaleY = place.worldScaleY;
		var originX = place.worldX;
		var originY = place.worldY;
		boundsLeft = FixedPoint.low(originX, width, scaleX);
		boundsRight = FixedPoint.high(originX, width, scaleX);
		boundsTop = FixedPoint.low(originY, height, scaleY);
		boundsBottom = FixedPoint.high(originY, height, scaleY);
		boundsDirty = false;
	}

	function refreshExact():Void {
		var sizeX:Single = width * place.worldScaleX;
		var sizeY:Single = height * place.worldScaleY;
		var originX = place.worldX;
		var originY = place.worldY;
		if (sizeX < ZERO) {
			exactLeft = originX + sizeX;
			exactRight = originX;
		} else {
			exactLeft = originX;
			exactRight = originX + sizeX;
		}
		if (sizeY < ZERO) {
			exactTop = originY + sizeY;
			exactBottom = originY;
		} else {
			exactTop = originY;
			exactBottom = originY + sizeY;
		}
		exactDirty = false;
	}

	public function overlaps(other:Collider2D):Bool {
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

	public function overlapsBox(x:Single, y:Single, width:Single, height:Single):Bool {
		if (boundsDirty) {
			refreshBounds();
		}
		return boundsLeft < FixedPoint.high(x, width, ONE) && boundsRight > FixedPoint.low(x, width, ONE) && boundsTop < FixedPoint.high(y, height, ONE)
			&& boundsBottom > FixedPoint.low(y, height, ONE);
	}

	public function containsPoint(x:Single, y:Single):Bool {
		if (boundsDirty) {
			refreshBounds();
		}
		var pointX = FixedPoint.point(x);
		var pointY = FixedPoint.point(y);
		return pointX >= boundsLeft && pointX < boundsRight && pointY >= boundsTop && pointY < boundsBottom;
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

	override function onDestroy():Void {
		debugRect = null;
		if (place != null && place.collider == this) {
			place.collider = null;
		}
	}

	function set_width(value:Single):Single {
		width = value;
		boundsDirty = true;
		exactDirty = true;
		queueForGrid();
		return value;
	}

	function set_height(value:Single):Single {
		height = value;
		boundsDirty = true;
		exactDirty = true;
		queueForGrid();
		return value;
	}

	function get_left():Single {
		if (exactDirty) {
			refreshExact();
		}
		return exactLeft;
	}

	function get_right():Single {
		if (exactDirty) {
			refreshExact();
		}
		return exactRight;
	}

	function get_top():Single {
		if (exactDirty) {
			refreshExact();
		}
		return exactTop;
	}

	function get_bottom():Single {
		if (exactDirty) {
			refreshExact();
		}
		return exactBottom;
	}

	function get_centerX():Single {
		return place.worldX + width * place.worldScaleX * HALF;
	}

	function get_centerY():Single {
		return place.worldY + height * place.worldScaleY * HALF;
	}
}
