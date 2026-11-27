package fried.scene.serialization;

class LegacyFields {
	public static function migrate(typeName:String, data:Dynamic):Void {
		if (typeName == "MeshInstance3D") {
			meshInstance(data);
		}
	}

	static function meshInstance(data:Dynamic):Void {
		if (!Reflect.hasField(data, "shape") && !Reflect.hasField(data, "color")) {
			return;
		}
		var shape = Reflect.hasField(data, "shape") ? Reflect.field(data, "shape") : "Cube";
		var color = Reflect.hasField(data, "color") ? Reflect.field(data, "color") : {r: 200, g: 200, b: 200, a: 255};
		Reflect.deleteField(data, "shape");
		Reflect.deleteField(data, "color");
		if (Reflect.hasField(data, "mesh")) {
			return;
		}
		var mesh:Dynamic = switch (shape) {
			case "Plane":
				// 16 by 16 tiles, which sorting by depth needs.
				{type: "PlaneMesh", sizeX: 1, sizeZ: 1, subdivideWidth: 15, subdivideDepth: 15};
			case "Sphere":
				{type: "SphereMesh", radialSegments: 8, rings: 6};
			case "Pyramid":
				// A four sided cone, turned an eighth of a turn about its axis.
				{
					type: "CylinderMesh",
					topRadius: 0,
					bottomRadius: 0.7071,
					height: 1,
					radialSegments: 4,
					rings: 0,
					capTop: false
				};
			case _:
				{type: "BoxMesh"};
		}
		Reflect.setField(mesh, "material", {type: "StandardMaterial3D", albedoColor: color});
		Reflect.setField(data, "mesh", mesh);
	}
}
