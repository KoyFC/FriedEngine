package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.Texture;
import fried.resources.Resource;

class Material extends Resource {
	// Goes up when the material changes, so a copy made before is made again.
	public var version(default, null):Int = 0;

	function changed():Void {
		version++;
	}

	public function albedo():Color {
		return Color.rgb(255, 255, 255);
	}

	public function albedoImage():Null<Texture> {
		return null;
	}

	public function fallbackColor():Color {
		var image = albedoImage();
		return image == null ? albedo() : MeshTools.multiply(albedo(), image.averageColor);
	}
}
