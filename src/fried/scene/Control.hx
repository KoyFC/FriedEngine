package fried.scene;

import fried.Log;
import fried.input.InputEvent;

// A node of the interface, placed against the rectangle of its parent instead of by a position.
//
// On each axis the anchors are fractions of the parent's rectangle. When the two are equal the control keeps its own size and sits at that point, moved by the pivot, a fraction of its own size, and then by the offset. When they differ it is stretched between the two anchors, shrunk by the insets.
//
// A control under another control is placed against that one's rectangle. Under a Node2D the parent's rectangle is a point at that node's position, so the offsets act as a position and the control follows it. Anywhere else, such as the root of a scene, it is the view.
//
// A control's own size is what the class says it is, such as a label's text, or else its width and height. A control with a size of its own that is stretched has its scale set to fill the space, which suits a texture and distorts a line of text; one without it is given the space as its size.
//
// Where a control is placed is worked out when it is read, and again only after something it depends on changed: its own fields, its parent's rectangle, the view, or the control it sits under with `below`.
@:serializable
class Control extends CanvasItem {
	public var anchorMinX(default, set):Float;
	public var anchorMinY(default, set):Float;
	public var anchorMaxX(default, set):Float;
	public var anchorMaxY(default, set):Float;
	public var pivotX(default, set):Float;
	public var pivotY(default, set):Float;
	public var offsetX(default, set):Float;
	public var offsetY(default, set):Float;
	public var insetLeft(default, set):Float;
	public var insetTop(default, set):Float;
	public var insetRight(default, set):Float;
	public var insetBottom(default, set):Float;

	// The size of a control that has none of its own.
	public var width(default, set):Float;
	public var height(default, set):Float;

	public var rotation(default, set):Float;
	public var scaleX(default, set):Float;
	public var scaleY(default, set):Float;

	// When set, the control is placed under this one instead of by its vertical anchor, with offsetY as the gap.
	public var below(default, set):Control;

	// The rectangle the control takes up in the world, after the scale.
	@:noSerialize public var rectWidth(get, never):Float;
	@:noSerialize public var rectHeight(get, never):Float;

	var rw:Float;
	var rh:Float;
	var dependents:Array<Control>;
	var isLayingOut:Bool;
	var isCycleReported:Bool;

	public function new(name:String = "Control") {
		super(name);
		anchorMinX = 0.0;
		anchorMinY = 0.0;
		anchorMaxX = 0.0;
		anchorMaxY = 0.0;
		pivotX = 0.0;
		pivotY = 0.0;
		offsetX = 0.0;
		offsetY = 0.0;
		insetLeft = 0.0;
		insetTop = 0.0;
		insetRight = 0.0;
		insetBottom = 0.0;
		width = 0.0;
		height = 0.0;
		rotation = 0.0;
		scaleX = 1.0;
		scaleY = 1.0;
		rw = 0.0;
		rh = 0.0;
		dependents = [];
		isLayingOut = false;
		isCycleReported = false;
	}

	// The size before the scale that a class gives its control, or a negative number when it gives none.
	function intrinsicWidth():Float {
		return -1;
	}

	function intrinsicHeight():Float {
		return -1;
	}

	// Where an event of the pointer or a finger is, in the space the control is drawn in: the screen under a CanvasLayer, the world through the scene's camera anywhere else.
	function eventX(event:InputEvent):Float {
		var camera = worldCamera();
		return camera != null ? camera.screenToWorldX(event.x) : event.x;
	}

	function eventY(event:InputEvent):Float {
		var camera = worldCamera();
		return camera != null ? camera.screenToWorldY(event.y) : event.y;
	}

	function worldCamera():Null<Camera> {
		if (scene == null) {
			return null;
		}
		var node = parent;
		while (node != null) {
			if (Std.isOfType(node, CanvasLayer)) {
				return null;
			}
			node = node.parent;
		}
		return scene.camera;
	}

	function containsEvent(event:InputEvent):Bool {
		var x = eventX(event);
		var y = eventY(event);
		var left = worldX;
		var top = worldY;
		var right = left + rectWidth;
		var bottom = top + rectHeight;
		return x >= Math.min(left, right) && x < Math.max(left, right) && y >= Math.min(top, bottom) && y < Math.max(top, bottom);
	}

	public function isStretchedX():Bool {
		return anchorMaxX != anchorMinX;
	}

	public function isStretchedY():Bool {
		return anchorMaxY != anchorMinY;
	}

	override function ensureWorld():Void {
		if (isLayingOut) {
			if (!isCycleReported) {
				isCycleReported = true;
				Log.warn('The layout of $name depends on itself, so one of the controls in the loop is placed before the other.');
			}
			return;
		}
		isLayingOut = true;
		worldDirty = false;

		var parentLeft = 0.0;
		var parentTop = 0.0;
		var parentWidth = 0.0;
		var parentHeight = 0.0;
		var container = parentItem;
		if (container != null) {
			if (container.worldDirty) {
				container.ensureWorld();
			}
			parentLeft = container.wx;
			parentTop = container.wy;
			var control = Std.downcast(container, Control);
			if (control != null) {
				parentWidth = control.rw;
				parentHeight = control.rh;
			}
		} else if (scene != null) {
			parentWidth = scene.viewWidth;
			parentHeight = scene.viewHeight;
		}

		var ownWidth = intrinsicWidth();
		var ownHeight = intrinsicHeight();
		var hasSize = ownWidth >= 0;
		var baseWidth = hasSize ? ownWidth : width;
		var baseHeight = hasSize ? ownHeight : height;
		var drawnScaleX = scaleX;
		var drawnScaleY = scaleY;

		var stretchedX = isStretchedX();
		var stretchedY = isStretchedY() && below == null;
		if (stretchedX) {
			var available = parentWidth * (anchorMaxX - anchorMinX) - insetLeft - insetRight;
			if (hasSize) {
				if (baseWidth > 0) {
					drawnScaleX = available / baseWidth;
				}
			} else {
				baseWidth = available;
				drawnScaleX = 1.0;
			}
		}
		if (stretchedY) {
			var available = parentHeight * (anchorMaxY - anchorMinY) - insetTop - insetBottom;
			if (hasSize) {
				if (baseHeight > 0) {
					drawnScaleY = available / baseHeight;
				}
			} else {
				baseHeight = available;
				drawnScaleY = 1.0;
			}
		}
		rw = baseWidth * drawnScaleX;
		rh = baseHeight * drawnScaleY;
		wsx = drawnScaleX;
		wsy = drawnScaleY;
		wrot = rotation;

		if (stretchedX) {
			wx = parentLeft + parentWidth * anchorMinX + insetLeft;
		} else {
			wx = parentLeft + parentWidth * anchorMinX - rw * pivotX + offsetX;
		}
		if (below != null) {
			wy = below.worldY + below.rh + offsetY;
		} else if (stretchedY) {
			wy = parentTop + parentHeight * anchorMinY + insetTop;
		} else {
			wy = parentTop + parentHeight * anchorMinY - rh * pivotY + offsetY;
		}
		isLayingOut = false;
	}

	override function markWorldDirty():Void {
		if (worldDirty) {
			return;
		}
		super.markWorldDirty();
		for (dependent in dependents) {
			dependent.markWorldDirty();
		}
	}

	override function viewChanged():Void {
		markWorldDirty();
	}

	inline function get_rectWidth():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return rw;
	}

	inline function get_rectHeight():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return rh;
	}

	function set_below(value:Control):Control {
		if (value == below) {
			return value;
		}
		if (below != null) {
			below.dependents.remove(this);
		}
		below = value;
		if (value != null) {
			value.dependents.push(this);
		}
		markWorldDirty();
		return value;
	}

	function set_anchorMinX(value:Float):Float {
		anchorMinX = value;
		markWorldDirty();
		return value;
	}

	function set_anchorMinY(value:Float):Float {
		anchorMinY = value;
		markWorldDirty();
		return value;
	}

	function set_anchorMaxX(value:Float):Float {
		anchorMaxX = value;
		markWorldDirty();
		return value;
	}

	function set_anchorMaxY(value:Float):Float {
		anchorMaxY = value;
		markWorldDirty();
		return value;
	}

	function set_pivotX(value:Float):Float {
		pivotX = value;
		markWorldDirty();
		return value;
	}

	function set_pivotY(value:Float):Float {
		pivotY = value;
		markWorldDirty();
		return value;
	}

	function set_offsetX(value:Float):Float {
		offsetX = value;
		markWorldDirty();
		return value;
	}

	function set_offsetY(value:Float):Float {
		offsetY = value;
		markWorldDirty();
		return value;
	}

	function set_insetLeft(value:Float):Float {
		insetLeft = value;
		markWorldDirty();
		return value;
	}

	function set_insetTop(value:Float):Float {
		insetTop = value;
		markWorldDirty();
		return value;
	}

	function set_insetRight(value:Float):Float {
		insetRight = value;
		markWorldDirty();
		return value;
	}

	function set_insetBottom(value:Float):Float {
		insetBottom = value;
		markWorldDirty();
		return value;
	}

	function set_width(value:Float):Float {
		width = value;
		markWorldDirty();
		return value;
	}

	function set_height(value:Float):Float {
		height = value;
		markWorldDirty();
		return value;
	}

	function set_rotation(value:Float):Float {
		rotation = value;
		markWorldDirty();
		return value;
	}

	function set_scaleX(value:Float):Float {
		scaleX = value;
		markWorldDirty();
		return value;
	}

	function set_scaleY(value:Float):Float {
		scaleY = value;
		markWorldDirty();
		return value;
	}
}
