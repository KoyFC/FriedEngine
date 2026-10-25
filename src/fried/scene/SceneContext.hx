package fried.scene;

import fried.Layer;
import fried.graphics.Renderer;

class SceneContext {
	public var name(default, null):String;

	var layers:Array<Layer>;
	var scenes:Array<Scene>;
	var unloadCallbacks:Array<Void->Void>;

	@:allow(fried.scene.SceneManager)
	function new(name:String) {
		this.name = name;
		layers = [];
		scenes = [];
		unloadCallbacks = [];
	}

	// Below every layer from outside this load, so those stay on top across loads.
	public function pushLayer<T:Layer>(renderer:Renderer, layer:T):T {
		var index = 0;
		for (position in 0...renderer.layers.length) {
			if (layers.indexOf(renderer.layers[position]) >= 0) {
				index = position + 1;
			}
		}
		renderer.insertLayer(index, layer);
		if (layers.indexOf(layer) < 0) {
			layers.push(layer);
		}
		return layer;
	}

	public function addScene(scene:Scene):Scene {
		scenes.push(scene);
		return scene;
	}

	public function pushScene(renderer:Renderer, scene:Scene):Scene {
		pushLayer(renderer, new SceneLayer(scene));
		return addScene(scene);
	}

	public function onUnload(callback:Void->Void):Void {
		unloadCallbacks.push(callback);
	}

	@:allow(fried.scene.SceneManager)
	function unload():Void {
		var index = unloadCallbacks.length - 1;
		while (index >= 0) {
			unloadCallbacks[index]();
			index--;
		}
		for (layer in layers) {
			if (layer.renderer != null) {
				layer.renderer.removeLayer(layer);
			}
		}
		for (scene in scenes) {
			scene.destroy();
		}
		unloadCallbacks.resize(0);
		layers.resize(0);
		scenes.resize(0);
	}
}
