package fried.scene.serialization;

import fried.Modules;
import haxe.macro.Expr;
#if macro
import haxe.macro.Context;
#end

class BuiltinsMacro {
	public static macro function componentList():Expr {
		return describe([
			"fried.scene.Component", "fried.scene.Transform", "fried.scene.Transform2D", "fried.scene.Transform3D", "fried.scene.RectTransform",
			"fried.scene.Renderer2D", "fried.scene.SpriteRenderer", "fried.scene.Camera", "fried.scene.Canvas", "fried.scene.Label",
			"fried.scene.TextureRect", "fried.scene.Button", "fried.scene.TouchButton", "fried.scene.VirtualJoystick", "fried.scene.Tilemap",
			"fried.physics2d.Collider2D", "fried.physics2d.Body2D", "fried.ui.UIDocument", "fried.scene.Camera3D", "fried.scene.MeshRenderer",
			"fried.scene.Light"
		], "describeComponent");
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
			var name = parts[parts.length - 1];
			if ((used == null || used.exists(name)) && !Modules.isLeftOutOfBuild(name)) {
				calls.push({expr: ECall({expr: EField(macro $p{parts}, method), pos: Context.currentPos()}, []), pos: Context.currentPos()});
			}
		}
		return macro $a{calls};
	}
	#end
}
