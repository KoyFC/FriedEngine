package fried.scene.serialization;

import fried.physics.Collider;
import fried.graphics3d.BoxMesh;
import fried.graphics3d.CapsuleMesh;
import fried.graphics3d.CylinderMesh;
import fried.graphics3d.PlaneMesh;
import fried.graphics3d.PrismMesh;
import fried.graphics3d.SphereMesh;
import fried.graphics3d.StandardMaterial3D;
import fried.graphics3d.TorusMesh;
import fried.physics.KinematicBody;

// A class only a scene file names is never typed by Haxe, so every node a scene may use is listed here, each after the class it extends.
class Builtins {
	public static function all():Array<NodeType> {
		return [Node.describeNode(), CanvasLayer.describeNode(), KinematicBody.describeNode(), CanvasItem.describeNode(), Node2D.describeNode(), Sprite.describeNode(), Tilemap.describeNode(), Camera.describeNode(), Collider.describeNode(), Control.describeNode(), fried.ui.UIDocument.describeNode(), Label.describeNode(), Button.describeNode(), TextureRect.describeNode(), TouchButton.describeNode(), VirtualJoystick.describeNode(), Node3D.describeNode(), Camera3D.describeNode(), DirectionalLight.describeNode(), MeshInstance3D.describeNode()];
	}

	// The same for the resources a field of a node may hold.
	public static function resources():Array<ResourceType> {
		return [
			StandardMaterial3D.describeResource(),
			BoxMesh.describeResource(),
			SphereMesh.describeResource(),
			CylinderMesh.describeResource(),
			CapsuleMesh.describeResource(),
			PlaneMesh.describeResource(),
			PrismMesh.describeResource(),
			TorusMesh.describeResource()
		];
	}
}
