package fried.scene.serialization;

import fried.graphics.Color;
import fried.graphics.Font;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics.Texture;
import fried.io.Filesystem;

// Converts between the data of a scene file and the values of component fields. The code a component's build macro generates calls these.
class FieldCodec {
	static var flipNames:Array<String> = ["None", "Horizontal", "Vertical", "Both"];

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
		return kind == Flip ? flipNames.copy() : [];
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
		return Font.from(assetPath(value, field), toInt(get(value, "size"), field));
	}

	public static function fromInt(value:Int):Dynamic {
		return value;
	}

	public static function fromFloat(value:Float):Dynamic {
		return value;
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

	public static function zeroInt():Int {
		return 0;
	}

	public static function zeroFloat():Float {
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

	public static function zeroRect():Rect {
		return null;
	}

	public static function zeroTexture():Texture {
		return null;
	}

	public static function zeroFont():Font {
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
			return invalid(field, "a colour channel from 0 to 255");
		}
		return number;
	}

	static function invalid<T>(field:String, expected:String):T {
		throw 'The scene data for "$field" must be $expected.';
	}
}
