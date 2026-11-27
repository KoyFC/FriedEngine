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
	}
}
