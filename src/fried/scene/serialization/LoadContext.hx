package fried.scene.serialization;

import fried.graphics.Renderer;

class LoadContext {
	// Textures belong to a renderer, so loading an asset reference needs one.
	public var renderer(default, null):Renderer;

	// Builds a component with a zero value for every constructor argument the data leaves out, instead of failing.
	public var usesZeroDefaults(default, null):Bool;

	public function new(renderer:Renderer, usesZeroDefaults:Bool = false) {
		this.renderer = renderer;
		this.usesZeroDefaults = usesZeroDefaults;
	}
}
