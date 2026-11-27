package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.Texture;

// A color, and optionally an image that it multiplies. A mesh is lit by flat shading, so there is no more to it than that.
@:serializable
class StandardMaterial3D extends Material {
	public var albedoColor(default, set):Color;
	public var albedoTexture(default, set):Texture;

	public function new() {
		super();
		@:bypassAccessor albedoColor = Color.rgb(255, 255, 255);
	}

	override public function albedo():Color {
		return albedoColor;
	}

	override public function albedoImage():Null<Texture> {
		return albedoTexture;
	}

	function set_albedoColor(value:Color):Color {
		albedoColor = value;
		changed();
		return value;
	}

	function set_albedoTexture(value:Texture):Texture {
		albedoTexture = value;
		changed();
		return value;
	}
}
