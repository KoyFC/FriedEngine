package fried.scene.serialization;

// What an editor offers for a field, spelled the way a scene file and the schema spell it.
enum abstract FieldKind(String) to String {
	var Integer = "int";
	var Number = "float";
	var Boolean = "bool";
	var Text = "string";
	var Rgba = "color";
	var Flip = "flip";
	var Region = "rect";
	var TextureRef = "texture";
	var FontRef = "font";
}
