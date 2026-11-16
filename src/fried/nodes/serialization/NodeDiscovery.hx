package fried.nodes.serialization;

import haxe.macro.Context;
import haxe.macro.Expr;

// Finds the nodes of a game, which are the @:serializable classes in the `nodes` package of its source, so no list has to be kept.
class NodeDiscovery {
	public static macro function register():Expr {
		var modules:Array<String> = [];
		for (root in Context.getClassPath()) {
			collect(haxe.io.Path.join([root, "nodes"]), "nodes", modules);
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
						var isNode = classType.pack.concat([classType.name]).join(".") == module;
						if (isNode && classType.meta.has(":serializable")) {
							var path = module.split(".");
							var name = path.pop();
							describes.push(macro $p{path.concat([name])}.describeNode());
						}
					case _:
				}
			}
		}
		return macro fried.nodes.serialization.NodeRegistry.register([$a{describes}]);
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
