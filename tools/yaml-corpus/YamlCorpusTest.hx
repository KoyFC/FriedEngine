import fried.io.Yaml;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class YamlCorpusTest {
	public static function same(a:Dynamic, b:Dynamic):Bool {
		if (Std.isOfType(a, Array) && Std.isOfType(b, Array)) {
			var x:Array<Dynamic> = a;
			var y:Array<Dynamic> = b;
			if (x.length != y.length) {
				return false;
			}
			for (i in 0...x.length) {
				if (!same(x[i], y[i])) {
					return false;
				}
			}
			return true;
		}
		if (Reflect.isObject(a) && Reflect.isObject(b) && !Std.isOfType(a, String) && !Std.isOfType(b, String)) {
			var fa = Reflect.fields(a);
			var fb = Reflect.fields(b);
			if (fa.length != fb.length) {
				return false;
			}
			for (f in fa) {
				if (!Reflect.hasField(b, f) || !same(Reflect.field(a, f), Reflect.field(b, f))) {
					return false;
				}
			}
			return true;
		}
		return a == b;
	}

	static function main() {
		var directory = ".";
		var failures = 0;
		var checked = 0;
		var files = FileSystem.readDirectory(directory).filter(f -> StringTools.endsWith(f, ".yaml"));
		files.sort(Reflect.compare);
		for (file in files) {
			checked++;
			var name = file.substr(0, file.length - 5);
			var source = File.getContent('$directory/$file');
			if (StringTools.startsWith(name, "error-")) {
				var wanted = StringTools.rtrim(File.getContent('$directory/$name.txt'));
				try {
					Yaml.parse(source, "f");
					Sys.println('FAIL $name: expected an error');
					failures++;
				} catch (message:String) {
					if (message != "f:" + wanted) {
						Sys.println('FAIL $name: expected "$wanted", got "$message"');
						failures++;
					}
				}
				continue;
			}
			try {
				var parsed = Yaml.parse(source, "f");
				var expected = Json.parse(File.getContent('$directory/$name.json'));
				if (!same(parsed, expected)) {
					Sys.println('FAIL $name: ${Json.stringify(parsed)} != ${Json.stringify(expected)}');
					failures++;
				}
			} catch (message:Dynamic) {
				Sys.println('FAIL $name: $message');
				failures++;
			}
		}
		Sys.println('$checked YAML cases, $failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
