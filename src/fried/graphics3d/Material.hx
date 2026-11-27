package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.Texture;
import fried.resources.Resource;

// How a surface of a mesh is painted. Anything that draws a mesh looks at version to know whether a material has changed since it last copied it.
class Material extends Resource {
	public var version(default, null):Int = 0;

	function changed():Void {
		version++;
	}

	// The color every triangle of the surface is multiplied by.
	public function albedo():Color {
		return Color.rgb(255, 255, 255);
	}

	// The image the surface is painted with, or null for a plain color.
	public function albedoImage():Null<Texture> {
		return null;
	}

	// What the surface looks like where a renderer cannot draw its image: the color, darkened by the image's average.
	public function fallbackColor():Color {
		var image = albedoImage();
		return image == null ? albedo() : MeshTools.multiply(albedo(), image.averageColor);
	}
}
