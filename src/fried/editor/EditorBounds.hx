package fried.editor;

#if fried_editor
import fried.physics2d.Collider2D;
import fried.scene.Camera;
import fried.scene.GameObject;
import fried.scene.RectTransform;
import fried.scene.SpriteRenderer;
import fried.scene.Tilemap;
import fried.scene.Transform;

typedef Box = {x:Float, y:Float, width:Float, height:Float}

// The box an object takes up in the world, which is what a click on it is tested against.
class EditorBounds {
	static inline var MARKER_SIZE:Float = 16.0;

	public static function of(object:GameObject):Box {
		var place = object.transform;
		var control = Std.downcast(place, RectTransform);
		if (control != null) {
			return box(control.worldX, control.worldY, control.rectWidth, control.rectHeight);
		}
		var sprite = object.getComponent(SpriteRenderer);
		if (sprite != null && sprite.texture != null) {
			var width = sprite.source != null ? sprite.source.width : sprite.texture.width;
			var height = sprite.source != null ? sprite.source.height : sprite.texture.height;
			return box(place.worldX, place.worldY, width * place.worldScaleX, height * place.worldScaleY);
		}
		var tilemap = object.getComponent(Tilemap);
		if (tilemap != null) {
			return box(place.worldX, place.worldY, tilemap.mapWidth * tilemap.tileWidth * place.worldScaleX, tilemap.mapHeight * tilemap.tileHeight * place.worldScaleY);
		}
		var collider = object.getComponent(Collider2D);
		if (collider != null) {
			return box(collider.left, collider.top, collider.right - collider.left, collider.bottom - collider.top);
		}
		// A component of the game that has a size of its own, such as a box, is measured by it.
		for (component in object.getComponents(fried.scene.Component)) {
			var width:Dynamic = Reflect.field(component, "width");
			var height:Dynamic = Reflect.field(component, "height");
			if (Std.isOfType(width, Int) && Std.isOfType(height, Int)) {
				return box(place.worldX, place.worldY, (width : Float) * place.worldScaleX, (height : Float) * place.worldScaleY);
			}
		}
		if (object.getComponent(Camera) != null) {
			return box(place.worldX - MARKER_SIZE / 2, place.worldY - MARKER_SIZE / 2, MARKER_SIZE, MARKER_SIZE);
		}
		return box(place.worldX, place.worldY, MARKER_SIZE, MARKER_SIZE);
	}

	// What the nearest ancestor that is placed on the plane gives an object, so the editor can turn a world position into the object's own.
	public static function parentOf(object:GameObject):Null<Dynamic> {
		var parent:Null<Transform> = object.transform.parent;
		while (parent != null && !parent.isPlaced2D()) {
			parent = parent.parent;
		}
		if (parent == null) {
			return null;
		}
		var control = Std.downcast(parent, RectTransform);
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
