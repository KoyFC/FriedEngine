package fried.scene.serialization;

import fried.graphics.Color;
import fried.graphics.Font;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics3d.Material;
import fried.graphics3d.Mesh;
import fried.graphics3d.MeshFile;
import fried.graphics3d.PlaneOrientation;
import fried.graphics.Texture;
import fried.io.Filesystem;
import fried.ui.HtmlSource;
import fried.ui.StyleSheet;

// Converts between the data of a scene file and the values of node fields. The code a node's build macro generates calls these.
class FieldCodec {
	static var flipNames:Array<String> = ["None", "Horizontal", "Vertical", "Both"];
	static var orientationNames:Array<String> = ["FaceX", "FaceY", "FaceZ"];

	public static function has(data:Dynamic, name:String):Bool {
		return data != null && Reflect.hasField(data, name);
	}

	public static function get(data:Dynamic, name:String):Dynamic {
		return Reflect.field(data, name);
	}

	public static function missing<T>(component:String, field:String):T {
		throw 'The data for $component has no "$field", which its constructor requires.';
	}

	public static function enumValues(kind:FieldKind):Array<String> {
		return switch (kind) {
			case Flip: flipNames.copy();
			case Orientation: orientationNames.copy();
			case _: [];
		}
	}

	public static function toInt(value:Dynamic, field:String):Int {
		if (Std.isOfType(value, Int)) {
			return value;
		}
		if (Std.isOfType(value, Float) && Math.floor(value) == value) {
			return Std.int(value);
		}
		return invalid(field, "a whole number");
	}

	public static function toFloat(value:Dynamic, field:String):Float {
		if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
			return value;
		}
		return invalid(field, "a number");
	}

	public static function toSingle(value:Dynamic, field:String):Single {
		if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
			return value;
		}
		return invalid(field, "a number");
	}

	public static function toBool(value:Dynamic, field:String):Bool {
		if (Std.isOfType(value, Bool)) {
			return value;
		}
		return invalid(field, "true or false");
	}

	public static function toText(value:Dynamic, field:String):String {
		if (Std.isOfType(value, String)) {
			return value;
		}
		return invalid(field, "text");
	}

	public static function toColor(value:Dynamic, field:String):Color {
		if (value == null || !Reflect.isObject(value)) {
			return invalid(field, "an object with r, g, b and optionally a");
		}
		var alpha = has(value, "a") ? channel(get(value, "a"), field) : 255;
		return Color.rgba(channel(get(value, "r"), field), channel(get(value, "g"), field), channel(get(value, "b"), field), alpha);
	}

	public static function toFlip(value:Dynamic, field:String):FlipMode {
		return switch (value) {
			case "None": FlipMode.None;
			case "Horizontal": FlipMode.Horizontal;
			case "Vertical": FlipMode.Vertical;
			case "Both": FlipMode.Both;
			case _: invalid(field, "one of " + flipNames.join(", "));
		}
	}

	public static function toOrientation(value:Dynamic, field:String):PlaneOrientation {
		return switch (value) {
			case "FaceX": PlaneOrientation.FaceX;
			case "FaceY": PlaneOrientation.FaceY;
			case "FaceZ": PlaneOrientation.FaceZ;
			case _: invalid(field, "one of " + orientationNames.join(", "));
		}
	}

	public static function toMesh(value:Dynamic, field:String, context:LoadContext):Mesh {
		if (value == null) {
			return null;
		}
		if (!Reflect.isObject(value)) {
			return invalid(field, "an object with a type, or with root and path");
		}
		if (has(value, "type")) {
			return cast ResourceRegistry.build(value, "mesh", field, context);
		}
		if (context.renderer == null) {
			throw 'Field "$field" names a model, which needs a renderer to load its images into.';
		}
		return MeshFile.load(context.renderer, assetPath(value, field), toText(get(value, "root"), field), toText(get(value, "path"), field));
	}

	public static function toMaterial(value:Dynamic, field:String, context:LoadContext):Material {
		if (value == null) {
			return null;
		}
		if (!Reflect.isObject(value)) {
			return invalid(field, "an object with a type");
		}
		return cast ResourceRegistry.build(value, "material", field, context);
	}

	public static function toRect(value:Dynamic, field:String):Rect {
		if (value == null) {
			return null;
		}
		if (!Reflect.isObject(value)) {
			return invalid(field, "an object with x, y, width and height, or null");
		}
		return new Rect(toInt(get(value, "x"), field), toInt(get(value, "y"), field), toInt(get(value, "width"), field), toInt(get(value, "height"), field));
	}

	public static function toTexture(value:Dynamic, field:String, context:LoadContext):Texture {
		if (value == null) {
			return null;
		}
		if (context.renderer == null) {
			throw 'Field "$field" names a texture, which needs a renderer to load into.';
		}
		return Texture.from(context.renderer, assetPath(value, field));
	}

	public static function toFont(value:Dynamic, field:String, context:LoadContext):Font {
		if (value == null) {
			return null;
		}
		var size = toInt(get(value, "size"), field);
		// A font may ask for a size on the output, which grows its logical size where the display shrinks the game.
		if (has(value, "minScreenSize") && context.renderer != null) {
			size = context.renderer.legibleSize(size, toInt(get(value, "minScreenSize"), field));
		}
		return Font.from(assetPath(value, field), size);
	}

	public static function toHtmlSource(value:Dynamic, field:String):HtmlSource {
		return value == null ? null : HtmlSource.from(assetPath(value, field));
	}

	public static function toStyleSheet(value:Dynamic, field:String):StyleSheet {
		return value == null ? null : StyleSheet.from(assetPath(value, field));
	}

	// A reference is the id of another object of the same scene. It stays null while the scene is still being built, and the loader assigns it afterward.
	public static function toObject(value:Dynamic, field:String, context:LoadContext):fried.scene.GameObject {
		if (value == null) {
			return null;
		}
		var id = toText(value, field);
		if (context.scene == null && context.scope == null) {
			return null;
		}
		var target = context.scope != null ? context.scope.objects.get(id) : context.scene.findById(id);
		if (target == null) {
			throw 'The field "$field" refers to the object "$id", which the scene does not have.';
		}
		return target;
	}

	public static function toComponent(value:Dynamic, field:String, context:LoadContext, type:Class<Dynamic>):fried.scene.Component {
		var target = toObject(value, field, context);
		if (target == null) {
			return null;
		}
		var found = target.getComponent(cast type);
		if (found == null) {
			throw 'The field "$field" refers to the object "${target.id}", which has no ${Type.getClassName(type)}.';
		}
		return found;
	}

	public static function fromObject(value:fried.scene.GameObject):Dynamic {
		return value == null ? null : value.id;
	}

	public static function fromComponent(value:fried.scene.Component):Dynamic {
		return value == null ? null : value.gameObject.id;
	}

	public static function zeroObject():fried.scene.GameObject {
		return null;
	}

	public static function zeroComponent():fried.scene.Component {
		return null;
	}

	public static function fromInt(value:Int):Dynamic {
		return value;
	}

	public static function fromFloat(value:Float):Dynamic {
		return value;
	}

	// The shortest decimal that reads back as the same single, so 0.1 is saved as 0.1 and not as the double it widens to.
	public static function fromSingle(value:Single):Dynamic {
		var exact:Float = value;
		var scale = 1.0;
		for (digits in 0...10) {
			var rounded = Math.ffloor(exact * scale + 0.5) / scale;
			if (((rounded : Single)) == value) {
				return rounded;
			}
			scale *= 10.0;
		}
		return exact;
	}

	public static function fromBool(value:Bool):Dynamic {
		return value;
	}

	public static function fromText(value:String):Dynamic {
		return value;
	}

	public static function fromColor(value:Color):Dynamic {
		return {r: value.red, g: value.green, b: value.blue, a: value.alpha};
	}

	public static function fromFlip(value:FlipMode):Dynamic {
		return flipNames[cast value];
	}

	public static function fromOrientation(value:PlaneOrientation):Dynamic {
		return orientationNames[cast value];
	}

	public static function fromMesh(value:Mesh):Dynamic {
		if (value != null && value.sourcePath != null) {
			return {root: value.sourceRoot, path: value.sourcePath};
		}
		return ResourceRegistry.describe(value);
	}

	public static function fromMaterial(value:Material):Dynamic {
		return ResourceRegistry.describe(value);
	}

	public static function fromRect(value:Rect):Dynamic {
		return value == null ? null : {x: value.x, y: value.y, width: value.width, height: value.height};
	}

	// A loaded asset does not remember where it came from.
	public static function fromTexture(value:Texture):Dynamic {
		return null;
	}

	public static function fromFont(value:Font):Dynamic {
		return null;
	}

	public static function fromHtmlSource(value:HtmlSource):Dynamic {
		return null;
	}

	public static function fromStyleSheet(value:StyleSheet):Dynamic {
		return null;
	}

	public static function zeroInt():Int {
		return 0;
	}

	public static function zeroFloat():Float {
		return 0.0;
	}

	public static function zeroSingle():Single {
		return 0.0;
	}

	public static function zeroBool():Bool {
		return false;
	}

	public static function zeroText():String {
		return "";
	}

	public static function zeroColor():Color {
		return Color.rgb(0, 0, 0);
	}

	public static function zeroFlip():FlipMode {
		return FlipMode.None;
	}

	public static function zeroOrientation():PlaneOrientation {
		return PlaneOrientation.FaceY;
	}

	public static function zeroMesh():Mesh {
		return null;
	}

	public static function zeroMaterial():Material {
		return null;
	}

	public static function zeroRect():Rect {
		return null;
	}

	public static function zeroTexture():Texture {
		return null;
	}

	public static function zeroFont():Font {
		return null;
	}

	public static function zeroHtmlSource():HtmlSource {
		return null;
	}

	public static function zeroStyleSheet():StyleSheet {
		return null;
	}

	static function assetPath(reference:Dynamic, field:String):String {
		if (!Reflect.isObject(reference)) {
			return invalid(field, "an object with root and path");
		}
		return Filesystem.resolveAsset(toText(get(reference, "root"), field), toText(get(reference, "path"), field));
	}

	static function channel(value:Dynamic, field:String):Int {
		var number = toInt(value, field);
		if (number < 0 || number > 255) {
			return invalid(field, "a color channel from 0 to 255");
		}
		return number;
	}

	static function invalid<T>(field:String, expected:String):T {
		throw 'The scene data for "$field" must be $expected.';
	}
}
