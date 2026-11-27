package fried.scene.serialization;

import fried.resources.Resource;
import fried.scene.serialization.FieldInfo;
import fried.scene.serialization.LoadContext;

// How a scene file builds and reads one class of resource. Unlike a node's type it holds the fields of the whole chain, since an inspector shows a resource as one list.
class ResourceType {
	public var name(default, null):String;

	// What the resource is for, which decides the fields it can be put in: "mesh" or "material".
	public var category(default, null):String;

	public var fields(default, null):Array<FieldInfo>;

	public var create(default, null):Dynamic->LoadContext->Resource;

	// The current value of every field, ready to be written as data.
	public var read(default, null):Resource->Dynamic;

	public function new(name:String, category:String, fields:Array<FieldInfo>, create:Dynamic->LoadContext->Resource, read:Resource->Dynamic) {
		this.name = name;
		this.category = category;
		this.fields = fields;
		this.create = create;
		this.read = read;
	}

	// What a resource of this class holds before a scene file says otherwise.
	public function defaultValues():Dynamic {
		return read(create({}, new LoadContext(null, true)));
	}
}
