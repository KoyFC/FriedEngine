package fried;

import fried.graphics.Renderer;
import fried.input.InputEvent;

class Layer {
	public var name:String;
	public var isEnabled:Bool;

	public var renderer(default, null):Renderer;

	public function new(name:String = "Layer") {
		this.name = name;
		isEnabled = true;
	}

	public function update():Void {}

	public function draw():Void {}

	public function onEvent(event:InputEvent):Void {}

	@:allow(fried.graphics.Renderer)
	function setRenderer(value:Renderer):Void {
		renderer = value;
	}
}
