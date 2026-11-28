package fried.scene;

// What a module adds to a scene's fixed step without the scene knowing it, such as the world of a physics backend: it is stepped after the bodies and the fixed updates, and disposed with the scene.
interface SceneStepper {
	function step(delta:Float):Void;
	function dispose():Void;
}
