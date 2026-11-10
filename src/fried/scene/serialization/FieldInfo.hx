package fried.scene.serialization;

class FieldInfo {
	public var name(default, null):String;
	public var kind(default, null):FieldKind;

	public function new(name:String, kind:FieldKind) {
		this.name = name;
		this.kind = kind;
	}
}
