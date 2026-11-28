package fried.editor;

#if fried_editor
import fried.graphics3d.Rotation;
import fried.scene.Camera3D;
import fried.scene.Transform3D;

// The volume a Camera3D sees, as eight corners in the world: those of its near plane and then those of its far plane. The view's own aspect shapes it, whatever the editor's panel looks like.
class EditorFrustum {
	static var turn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

	public static function of(camera:Camera3D, aspect:Float):Dynamic {
		var place = camera.gameObject.getComponent(Transform3D);
		Rotation.toMatrix(place.worldRotationX, place.worldRotationY, place.worldRotationZ, turn);
		var tangent = Math.tan(camera.fieldOfView * Math.PI / 360.0);
		var corners:Array<Float> = [];
		for (plane in 0...2) {
			var distance = plane == 0 ? camera.near : camera.far;
			var halfHeight = distance * tangent;
			var halfWidth = halfHeight * aspect;
			for (corner in 0...4) {
				var across = (corner == 1 || corner == 2 ? 1.0 : -1.0) * halfWidth;
				var up = corner >= 2 ? halfHeight : -halfHeight;
				corners.push(place.worldX + turn[0] * across + turn[1] * up + turn[2] * distance);
				corners.push(place.worldY + turn[3] * across + turn[4] * up + turn[5] * distance);
				corners.push(place.worldZ + turn[6] * across + turn[7] * up + turn[8] * distance);
			}
		}
		return {id: camera.gameObject.id, corners: corners};
	}
}
#end
