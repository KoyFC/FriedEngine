package fried.nodes.editor;

#if fried_editor
import fried.nodes.physics.Collider;

typedef Box = {x:Float, y:Float, width:Float, height:Float}

// The box a node takes up in the world, which is what a click on it is tested against.
class EditorBounds {
	static inline var MARKER_SIZE:Float = 16.0;

	public static function of(node:CanvasItem):Box {
		var control = Std.downcast(node, Control);
		if (control != null) {
			return box(control.worldX, control.worldY, control.rectWidth, control.rectHeight);
		}
		var sprite = Std.downcast(node, Sprite);
		if (sprite != null && sprite.texture != null) {
			var width = sprite.source != null ? sprite.source.width : sprite.texture.width;
			var height = sprite.source != null ? sprite.source.height : sprite.texture.height;
			return box(sprite.worldX, sprite.worldY, width * sprite.worldScaleX, height * sprite.worldScaleY);
		}
		var collider = Std.downcast(node, Collider);
		if (collider != null) {
			return box(collider.left, collider.top, collider.right - collider.left, collider.bottom - collider.top);
		}
		// A node of the game that has a size of its own, such as a box, is measured by it.
		var width:Dynamic = Reflect.field(node, "width");
		var height:Dynamic = Reflect.field(node, "height");
		if (Std.isOfType(width, Int) && Std.isOfType(height, Int)) {
			return box(node.worldX, node.worldY, width * node.worldScaleX, height * node.worldScaleY);
		}
		if (Std.isOfType(node, Camera)) {
			return box(node.worldX - MARKER_SIZE / 2, node.worldY - MARKER_SIZE / 2, MARKER_SIZE, MARKER_SIZE);
		}
		return box(node.worldX, node.worldY, MARKER_SIZE, MARKER_SIZE);
	}

	// What the nearest ancestor that is drawn gives a node, so the editor can turn a world position into the node's own.
	public static function parentOf(node:CanvasItem):Null<Dynamic> {
		var parent = node.parentItem;
		if (parent == null) {
			return null;
		}
		var control = Std.downcast(parent, Control);
		return {
			x: parent.worldX,
			y: parent.worldY,
			rotation: parent.worldRotation,
			scaleX: parent.worldScaleX,
			scaleY: parent.worldScaleY,
			width: control != null ? control.rectWidth : 0,
			height: control != null ? control.rectHeight : 0
		};
	}

	// A negative scale flips the box, and a box is described from its top left corner.
	static function box(x:Float, y:Float, width:Float, height:Float):Box {
		return {
			x: width < 0 ? x + width : x,
			y: height < 0 ? y + height : y,
			width: Math.abs(width),
			height: Math.abs(height)
		};
	}
}
#end
