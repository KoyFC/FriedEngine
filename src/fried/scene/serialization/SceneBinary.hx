package fried.scene.serialization;

import haxe.io.Bytes;

// Reads a scene compiled by tools/fried_import (docs/architecture/scene-files.md) into what `haxe.Json.parse` gives for the text it came from, so nothing after loading knows the difference.
class SceneBinary {
	public static inline var FORMAT:Int = 1;

	public static function decode(bytes:Bytes, fileName:String):Dynamic {
		if (bytes.length < 12 || bytes.getString(0, 4) != "FSCN") {
			throw 'The scene file $fileName is not a compiled scene. Build the assets again.';
		}
		var format = bytes.getUInt16(4);
		if (format != FORMAT) {
			throw 'The scene file $fileName is compiled in format $format, and this engine reads format $FORMAT. Build the assets again.';
		}
		var count = bytes.getInt32(8);
		var strings:Array<String> = [];
		var at = 12;
		for (_ in 0...count) {
			var length = bytes.getInt32(at);
			strings.push(bytes.getString(at + 4, length));
			at += 4 + length;
		}
		var reader = new ValueReader(bytes, strings, (at + 3) & ~3);
		return reader.read();
	}
}

private class ValueReader {
	var bytes:Bytes;
	var strings:Array<String>;
	var at:Int;

	public function new(bytes:Bytes, strings:Array<String>, at:Int) {
		this.bytes = bytes;
		this.strings = strings;
		this.at = at;
	}

	public function read():Dynamic {
		var tag = bytes.get(at++);
		switch (tag) {
			case 0:
				return null;
			case 1:
				return false;
			case 2:
				return true;
			case 3:
				var integer = bytes.getInt32(at);
				at += 4;
				return integer;
			case 4:
				var single = bytes.getFloat(at);
				at += 4;
				return single;
			case 5:
				var double = bytes.getDouble(at);
				at += 8;
				return double;
			case 6:
				var text = strings[bytes.getInt32(at)];
				at += 4;
				return text;
			case 7:
				var length = bytes.getInt32(at);
				at += 4;
				var array:Array<Dynamic> = [];
				for (_ in 0...length) {
					array.push(read());
				}
				return array;
			case 8:
				var length = bytes.getInt32(at);
				at += 4;
				var object:Dynamic = {};
				for (_ in 0...length) {
					var key = strings[bytes.getInt32(at)];
					at += 4;
					Reflect.setField(object, key, read());
				}
				return object;
			default:
				throw 'The compiled scene has the unknown value tag $tag.';
		}
	}
}
