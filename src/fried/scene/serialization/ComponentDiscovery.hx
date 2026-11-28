package fried.scene.serialization;

import haxe.macro.Context;
import haxe.macro.Expr;

// Finds the components of a game, which are the @:serializable classes in the `components` package of its source, so no list has to be kept.
class ComponentDiscovery {
	public static macro function register():Expr {
		var modules:Array<String> = [];
		for (root in Context.getClassPath()) {
			collect(haxe.io.Path.join([root, "components"]), "components", modules);
		}

		var describes:Array<Expr> = [];
		var seen = new Map<String, Bool>();
		for (module in modules) {
			if (seen.exists(module)) {
				continue;
			}
			seen.set(module, true);
			for (type in Context.getModule(module)) {
				switch (type) {
					case TInst(reference, _):
						var classType = reference.get();
						var isComponent = classType.pack.concat([classType.name]).join(".") == module;
						if (isComponent && classType.meta.has(":serializable")) {
							var path = module.split(".");
							var name = path.pop();
							describes.push(macro $p{path.concat([name])}.describeComponent());
						}
					case _:
				}
			}
		}
		return macro fried.scene.serialization.ComponentRegistry.register([$a{describes}]);
	}

	static function collect(directory:String, prefix:String, modules:Array<String>):Void {
		if (!sys.FileSystem.exists(directory) || !sys.FileSystem.isDirectory(directory)) {
			return;
		}
		for (entry in sys.FileSystem.readDirectory(directory)) {
			var path = haxe.io.Path.join([directory, entry]);
			if (sys.FileSystem.isDirectory(path)) {
				collect(path, prefix + "." + entry, modules);
			} else if (StringTools.endsWith(entry, ".hx")) {
				modules.push(prefix + "." + entry.substr(0, entry.length - 3));
			}
		}
	}
}
