package fried.scene;

// The transform of an object of the interface, which takes the place of its Transform, as in Unity. It places the object in the view, as a rectangle does there: against the view's edges, whatever its size, and in the editor as in the game.
//
// On each axis the anchors are fractions of the view. When the two are equal the object keeps its own size and sits at that point, moved by the pivot, a fraction of its own size, and then by the offset. When they differ the object is stretched between the two anchors, shrunk by the insets, and its scale takes the size it is given.
//
// Stretching is done by the transform's scale, so it suits a sprite or a box and distorts a line of text, which a FitText sizes instead.
//
// What it places is its own x and y, and the scale where it stretches, so what a file holds for those is overwritten by every layout and the offsets and insets are what to edit. Rotation is left to the file.
//
// An object can instead sit under another one, with the offset as the gap. A line of text that must shrink to fit puts a FitText of the game before this in the layout, which is sized first.
@:serializable
class RectTransform extends Transform {
	public var anchorMinX:Float;
	public var anchorMinY:Float;
	public var anchorMaxX:Float;
	public var anchorMaxY:Float;
	public var pivotX:Float;
	public var pivotY:Float;
	public var offsetX:Float;
	public var offsetY:Float;
	public var insetLeft:Float;
	public var insetTop:Float;
	public var insetRight:Float;
	public var insetBottom:Float;

	// When set, the object is placed under this one instead of by its vertical anchor, with offsetY as the gap.
	public var below:GameObject;

	public function new(anchorMinX:Float = 0.0, anchorMinY:Float = 0.0, anchorMaxX:Float = 0.0, anchorMaxY:Float = 0.0, pivotX:Float = 0.0, pivotY:Float = 0.0,
			offsetX:Float = 0.0, offsetY:Float = 0.0, insetLeft:Float = 0.0, insetTop:Float = 0.0, insetRight:Float = 0.0, insetBottom:Float = 0.0) {
		super();
		this.anchorMinX = anchorMinX;
		this.anchorMinY = anchorMinY;
		this.anchorMaxX = anchorMaxX;
		this.anchorMaxY = anchorMaxY;
		this.pivotX = pivotX;
		this.pivotY = pivotY;
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		this.insetLeft = insetLeft;
		this.insetTop = insetTop;
		this.insetRight = insetRight;
		this.insetBottom = insetBottom;
	}

	public var isStretchedX(get, never):Bool;
	public var isStretchedY(get, never):Bool;

	override function layoutAfter():Null<GameObject> {
		return below;
	}

	override function layoutSize():Void {
		var scene = gameObject.scene;
		if (isStretchedX) {
			var width = gameObject.intrinsicWidth();
			if (width > 0) {
				transform.scaleX = (scene.viewWidth * (anchorMaxX - anchorMinX) - insetLeft - insetRight) / width;
			}
		}
		if (isStretchedY && below == null) {
			var height = gameObject.intrinsicHeight();
			if (height > 0) {
				transform.scaleY = (scene.viewHeight * (anchorMaxY - anchorMinY) - insetTop - insetBottom) / height;
			}
		}
	}

	override function layoutPosition():Void {
		var scene = gameObject.scene;
		if (isStretchedX) {
			transform.x = scene.viewWidth * anchorMinX + insetLeft;
		} else {
			transform.x = scene.viewWidth * anchorMinX - gameObject.intrinsicWidth() * transform.scaleX * pivotX + offsetX;
		}
		if (below != null) {
			transform.y = below.transform.y + below.intrinsicHeight() * below.transform.scaleY + offsetY;
		} else if (isStretchedY) {
			transform.y = scene.viewHeight * anchorMinY + insetTop;
		} else {
			transform.y = scene.viewHeight * anchorMinY - gameObject.intrinsicHeight() * transform.scaleY * pivotY + offsetY;
		}
	}

	function get_isStretchedX():Bool {
		return anchorMaxX != anchorMinX;
	}

	function get_isStretchedY():Bool {
		return anchorMaxY != anchorMinY;
	}
}
