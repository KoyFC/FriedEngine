package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.Texture;

// What a mesh looks like once the materials that paint it are known: the color of each triangle, and the image if it has one. A mesh keeps one for each material a node overrides it with, and makes it again when a material changes.
class MeshVariant {
	public var overriding(default, null):Null<Material>;
	public var versions(default, null):Array<Int>;

	// One for each triangle: its own color multiplied by its surface's albedo.
	public var colors(default, null):Array<Color>;

	// One for each surface.
	public var textures(default, null):Array<Null<Texture>>;

	public var nativeId:Int = -1;

	public function new(overriding:Null<Material>, versions:Array<Int>, colors:Array<Color>, textures:Array<Null<Texture>>) {
		this.overriding = overriding;
		this.versions = versions;
		this.colors = colors;
		this.textures = textures;
	}
}
