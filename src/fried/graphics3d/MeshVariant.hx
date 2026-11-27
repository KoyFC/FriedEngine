package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.Texture;

class MeshVariant {
	public var overriding(default, null):Null<Material>;
	public var versions(default, null):Array<Int>;

	public var colors(default, null):Array<Color>;

	public var textures(default, null):Array<Null<Texture>>;

	public var nativeId:Int = -1;

	public function new(overriding:Null<Material>, versions:Array<Int>, colors:Array<Color>, textures:Array<Null<Texture>>) {
		this.overriding = overriding;
		this.versions = versions;
		this.colors = colors;
		this.textures = textures;
		cpp.vm.Gc.setFinalizer(this, cpp.Function.fromStaticFunction(release));
	}

	// A mesh a scene made goes with the scene without anyone destroying it, so its native half is freed when the collector takes the variant. Mesh.destroy() has set nativeId to -1 if it already did.
	static function release(variant:MeshVariant):Void {
		if (variant.nativeId >= 0) {
			MeshVariantNative.destroy(variant.nativeId);
			variant.nativeId = -1;
		}
	}
}

@:include("graphics/mesh.h")
private extern class MeshVariantNative {
	@:native("fried_mesh_destroy")
	static function destroy(meshId:Int):Void;
}
