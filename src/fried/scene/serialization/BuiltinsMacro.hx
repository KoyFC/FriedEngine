package fried.scene.serialization;

import haxe.macro.Expr;
#if macro
import haxe.macro.Context;
#end

class BuiltinsMacro {
	public static macro function nodeList():Expr {
		return describe([
			"fried.scene.Node", "fried.scene.CanvasLayer", "fried.physics.KinematicBody", "fried.scene.CanvasItem", "fried.scene.Node2D", "fried.scene.Sprite",
			"fried.scene.Tilemap", "fried.scene.Camera", "fried.physics.Collider", "fried.scene.Control", "fried.ui.UIDocument", "fried.scene.Label",
			"fried.scene.Button", "fried.scene.TextureRect", "fried.scene.TouchButton", "fried.scene.VirtualJoystick", "fried.scene.Node3D",
			"fried.scene.Camera3D", "fried.scene.DirectionalLight", "fried.scene.MeshInstance3D"
		], "describeNode");
	}

	public static macro function resourceList():Expr {
		return describe([
			"fried.graphics3d.StandardMaterial3D", "fried.graphics3d.BoxMesh", "fried.graphics3d.SphereMesh", "fried.graphics3d.CylinderMesh",
			"fried.graphics3d.CapsuleMesh", "fried.graphics3d.PlaneMesh", "fried.graphics3d.PrismMesh", "fried.graphics3d.TorusMesh"
		], "describeResource");
	}

	#if macro
	static function describe(paths:Array<String>, method:String):Expr {
		var used = UsedTypes.names();
		var calls = [];
		for (path in paths) {
			var parts = path.split(".");
			if (used == null || used.exists(parts[parts.length - 1])) {
				calls.push({expr: ECall({expr: EField(macro $p{parts}, method), pos: Context.currentPos()}, []), pos: Context.currentPos()});
			}
		}
		return macro $a{calls};
	}
	#end
}
