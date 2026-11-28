package fried.scene.serialization;

// The ids of the objects of one scene file that is instanced as an object. They are local to the instance, so two instances of a file never clash and a file's own references mean its own objects.
class InstanceScope {
	public var root:GameObject;
	public var objects:Map<String, GameObject> = new Map();

	public function new() {}
}
