package fried.scene.serialization;

import fried.graphics.Renderer;

class LoadContext {
	// Textures belong to a renderer, so loading an asset reference needs one.
	public var renderer(default, null):Renderer;

	// Builds a node with a zero value for every constructor argument the data leaves out, instead of failing.
	public var usesZeroDefaults(default, null):Bool;

	// The scene being built. It is null until every node exists, so a reference to another node cannot be resolved before then.
	public var scene:Scene;

	public function new(renderer:Renderer, usesZeroDefaults:Bool = false) {
		this.renderer = renderer;
		this.usesZeroDefaults = usesZeroDefaults;
	}
}
