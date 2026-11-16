package fried.scene.serialization;

import fried.scene.serialization.FieldInfo;
import fried.scene.serialization.LoadContext;

// How a scene file builds and reads one class of node. It holds only the fields the class declares itself: the ones it inherits belong to the types above it, which is also how an inspector groups them.
class NodeType {
	public var name(default, null):String;

	// The nearest serializable class above this one, or null for the root of the tree.
	public var parent(default, null):Null<String>;

	public var fields(default, null):Array<FieldInfo>;

	// Builds a node from the data of a scene file, with the fields of every class in its chain.
	public var create(default, null):Dynamic->LoadContext->Node;

	// Assigns the fields the data holds, of every class in the chain, to a node that already exists.
	public var apply(default, null):Node->Dynamic->LoadContext->Void;

	// The current value of every field of the chain, ready to be written as data.
	public var read(default, null):Node->Dynamic;

	public function new(name:String, parent:Null<String>, fields:Array<FieldInfo>, create:Dynamic->LoadContext->Node,
			apply:Node->Dynamic->LoadContext->Void, read:Node->Dynamic) {
		this.name = name;
		this.parent = parent;
		this.fields = fields;
		this.create = create;
		this.apply = apply;
		this.read = read;
	}

	// What a node of this class holds before a scene file says otherwise.
	public function defaultValues():Dynamic {
		return read(create({}, new LoadContext(null, true)));
	}
}
