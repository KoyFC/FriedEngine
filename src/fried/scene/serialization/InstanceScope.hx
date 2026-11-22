package fried.scene.serialization;

// The ids of the nodes of one scene file that is instanced as a node. They are local to the instance, so two instances of a file never clash and a file's own references mean its own nodes.
class InstanceScope {
	public var root:Node;
	public var nodes:Map<String, Node> = new Map();

	public function new() {}
}
