package fried.scene.serialization;

import fried.resources.Resource;
import fried.scene.serialization.FieldInfo;
import fried.scene.serialization.LoadContext;

class ResourceType {
	public var name(default, null):String;

	public var category(default, null):String;

	public var fields(default, null):Array<FieldInfo>;

	public var create(default, null):Dynamic->LoadContext->Resource;

	public var read(default, null):Resource->Dynamic;

	public function new(name:String, category:String, fields:Array<FieldInfo>, create:Dynamic->LoadContext->Resource, read:Resource->Dynamic) {
		this.name = name;
		this.category = category;
		this.fields = fields;
		this.create = create;
		this.read = read;
	}

	public function defaultValues():Dynamic {
		return read(create({}, new LoadContext(null, true)));
	}
}
