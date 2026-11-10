package fried.editor;

#if fried_editor
import fried.physics.Collider;
import fried.scene.Button;
import fried.scene.Camera;
import fried.scene.GameObject;
import fried.scene.Sprite;
import fried.scene.Text;

// The box an object takes up in the world, which is what a click on it is tested against.
class EditorBounds {
	static inline var MARKER_SIZE:Float = 16.0;

	public static function of(object:GameObject):{x:Float, y:Float, width:Float, height:Float} {
		var transform = object.transform;
		var sprite = object.getComponent(Sprite);
		if (sprite != null && sprite.texture != null) {
			var width = sprite.source != null ? sprite.source.width : sprite.texture.width;
			var height = sprite.source != null ? sprite.source.height : sprite.texture.height;
			return box(transform.x, transform.y, width * transform.scaleX, height * transform.scaleY);
		}
		var text = object.getComponent(Text);
		if (text != null && text.font != null) {
			return box(transform.x, transform.y, text.width * transform.scaleX, text.height * transform.scaleY);
		}
		var button = object.getComponent(Button);
		if (button != null) {
			return box(transform.x, transform.y, button.width * transform.scaleX, button.height * transform.scaleY);
		}
		var collider = object.getComponent(Collider);
		if (collider != null) {
			return box(collider.left, collider.top, collider.right - collider.left, collider.bottom - collider.top);
		}
		for (component in object.components) {
			// A component of the game that has a size of its own, such as a box, is measured by it.
			var width:Dynamic = Reflect.field(component, "width");
			var height:Dynamic = Reflect.field(component, "height");
			if (Std.isOfType(width, Int) && Std.isOfType(height, Int)) {
				return box(transform.x, transform.y, width * transform.scaleX, height * transform.scaleY);
			}
		}
		if (object.getComponent(Camera) != null) {
			return box(transform.x - MARKER_SIZE / 2, transform.y - MARKER_SIZE / 2, MARKER_SIZE, MARKER_SIZE);
		}
		return box(transform.x, transform.y, MARKER_SIZE, MARKER_SIZE);
	}

	// A negative scale flips the box, and a box is described from its top left corner.
	static function box(x:Float, y:Float, width:Float, height:Float):{x:Float, y:Float, width:Float, height:Float} {
		return {
			x: width < 0 ? x + width : x,
			y: height < 0 ? y + height : y,
			width: Math.abs(width),
			height: Math.abs(height)
		};
	}
}
#end
