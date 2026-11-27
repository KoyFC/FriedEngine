package fried.resources;

// Data that a scene file holds inside a field, as a mesh or a material, and not as a node of its own. A class marked @:serializable gets a static describeResource(), which is how a scene file builds it and reads it back.
@:autoBuild(fried.scene.serialization.ResourceBuilder.build())
class Resource {
	public function new() {}
}
