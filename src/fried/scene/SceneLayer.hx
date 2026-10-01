package fried.scene;

import fried.Layer;

class SceneLayer extends Layer {
	public var scene(default, null):Scene;

	public function new(scene:Scene, ?name:String) {
		super(name == null ? scene.name : name);
		this.scene = scene;
	}

	override function update():Void {
		scene.update();
	}

	override function draw():Void {
		scene.draw(renderer);
	}
}
