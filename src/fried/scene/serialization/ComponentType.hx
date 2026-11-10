package fried.scene.serialization;

class ComponentType {
	public var name(default, null):String;
	public var fields(default, null):Array<FieldInfo>;

	// Builds a component from the data of a scene file.
	public var create(default, null):Dynamic->LoadContext->Component;

	// Assigns the fields the data holds to a component that already exists.
	public var apply(default, null):Component->Dynamic->LoadContext->Void;

	// The current value of every field, ready to be written as data.
	public var read(default, null):Component->Dynamic;

	public function new(name:String, fields:Array<FieldInfo>, create:Dynamic->LoadContext->Component, apply:Component->Dynamic->LoadContext->Void,
			read:Component->Dynamic) {
		this.name = name;
		this.fields = fields;
		this.create = create;
		this.apply = apply;
		this.read = read;
	}

	// What a component of this type holds before a scene file says otherwise.
	public function defaultValues():Dynamic {
		return read(create({}, new LoadContext(null, true)));
	}
}
