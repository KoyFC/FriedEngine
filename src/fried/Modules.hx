package fried;

import haxe.macro.Expr;
#if macro
import haxe.macro.Context;
#end

// What the engine's modules (modules.json) are set to in project.fried, for each platform. A module has backends that do not run on every platform; the build keeps the code of the backends some platform uses and the scenes drop what a platform does not use.
class Modules {
	#if macro
	static final platforms = ["pc", "vita", "switch", "3ds", "nds", "cg50", "web", "android"];
	static var manifestData:Dynamic;
	static var resolvedData:Map<String, Map<String, String>>;
	static var isChecking:Bool = false;

	static function manifest():Dynamic {
		if (manifestData == null) {
			var project = Context.resolvePath("fried/Project.hx");
			var path = haxe.io.Path.join([haxe.io.Path.directory(project), "..", "..", "modules.json"]);
			try {
				manifestData = haxe.Json.parse(sys.io.File.getContent(path));
			} catch (e:Dynamic) {
				Context.fatalError('The module manifest $path cannot be read: $e', Context.currentPos());
			}
		}
		return manifestData;
	}

	static function backendsOf(module:String):Dynamic {
		return Reflect.field(Reflect.field(manifest(), module), "backends");
	}

	static function runsOn(backend:Dynamic, platform:String):Bool {
		var allowed:Dynamic = Reflect.field(backend, "platforms");
		return allowed == "all" || (Std.isOfType(allowed, Array) && (allowed : Array<String>).indexOf(platform) >= 0);
	}

	static function choicesOf(node:Dynamic, place:String):Map<String, String> {
		var choices = new Map<String, String>();
		var modules:Dynamic = node == null ? null : Reflect.field(node, "modules");
		if (modules == null) {
			return choices;
		}
		for (module in Reflect.fields(modules)) {
			if (!Reflect.hasField(manifest(), module)) {
				Context.error('project.fried gives "$place" the module "$module", which is not one of: ${Reflect.fields(manifest()).join(", ")}.', Context.currentPos());
			}
			var name:Dynamic = Reflect.field(modules, module);
			var backends = backendsOf(module);
			var backend:Dynamic = Std.isOfType(name, String) ? Reflect.field(backends, name) : null;
			if (backend == null) {
				Context.error('project.fried gives "$place.$module" the backend "$name", which is not one of: ${Reflect.fields(backends).join(", ")}.', Context.currentPos());
			}
			if (Reflect.field(backend, "planned") == true) {
				Context.error('project.fried gives "$place.$module" the backend "$name", which is planned and cannot be chosen yet.', Context.currentPos());
			}
			choices.set(module, name);
		}
		return choices;
	}

	// The platforms the project declares, which are every platform when it does not say.
	static function declaredPlatforms(project:Dynamic):Array<String> {
		var declared:Dynamic = Reflect.field(project, "platforms");
		if (Std.isOfType(declared, Array)) {
			return [for (name in (declared : Array<Dynamic>)) Std.string(name)];
		}
		if (Reflect.isObject(declared) && !Std.isOfType(declared, String)) {
			return Reflect.fields(declared);
		}
		return platforms.copy();
	}

	// The backend of every module on each platform the project declares: the platform's own choice, else the project's, else the module's default.
	public static function resolved():Map<String, Map<String, String>> {
		if (resolvedData != null) {
			return resolvedData;
		}
		resolvedData = new Map();
		if (!Project.projectExists()) {
			return resolvedData;
		}
		var project:Dynamic = Project.read();
		var shared = choicesOf(project, "modules");
		var profiles:Dynamic = Reflect.field(project, "platforms");
		var isMap = Reflect.isObject(profiles) && !Std.isOfType(profiles, Array) && !Std.isOfType(profiles, String);
		for (platform in declaredPlatforms(project)) {
			var own = isMap ? choicesOf(Reflect.field(profiles, platform), 'platforms.$platform.modules') : new Map<String, String>();
			var chosen = new Map<String, String>();
			for (module in Reflect.fields(manifest())) {
				var name = own.exists(module) ? own.get(module) : shared.exists(module) ? shared.get(module) : Reflect.field(Reflect.field(manifest(), module), "default");
				if (!runsOn(Reflect.field(backendsOf(module), name), platform)) {
					var fallback = Reflect.field(Reflect.field(manifest(), module), "default");
					Context.error('project.fried: $module: $name does not run on $platform. Set "platforms.$platform.modules.$module" to $fallback.', Context.currentPos());
				}
				chosen.set(module, name);
			}
			resolvedData.set(platform, chosen);
		}
		return resolvedData;
	}

	// The module and backend a component belongs to, if it belongs to one.
	public static function ownerOf(component:String):Null<{module:String, backend:String}> {
		for (module in Reflect.fields(manifest())) {
			var backends = backendsOf(module);
			for (backend in Reflect.fields(backends)) {
				for (list in ["components", "classes"]) {
					var names:Dynamic = Reflect.field(Reflect.field(backends, backend), list);
					if (Std.isOfType(names, Array) && (names : Array<String>).indexOf(component) >= 0) {
						return {module: module, backend: backend};
					}
				}
			}
		}
		return null;
	}

	static function isUsedAnywhere(module:String, backend:String):Bool {
		for (chosen in resolved()) {
			if (chosen.get(module) == backend) {
				return true;
			}
		}
		return false;
	}

	// Whether the build leaves out the code of the component's backend, because no platform of the project uses it. Only a backend with a native part of its own is left out: the others are used by the engine itself.
	public static function isLeftOutOfBuild(component:String):Bool {
		var owner = ownerOf(component);
		if (owner == null || Context.defined("fried_editor") || !Project.projectExists()) {
			return false;
		}
		var backend = Reflect.field(backendsOf(owner.module), owner.backend);
		return Reflect.hasField(backend, "native") && !isUsedAnywhere(owner.module, owner.backend);
	}

	static function isDegraded(module:String, backend:String, platform:String):Bool {
		var degraded:Dynamic = Reflect.field(Reflect.field(backendsOf(module), backend), "degraded");
		return degraded != null && Reflect.hasField(degraded, platform);
	}

	// A class of a backend that no platform uses has no native code to run on, so a game that names one is refused here and not by the linker.
	public static function checkGenerated():Void {
		if (isChecking) {
			return;
		}
		isChecking = true;
		Context.onGenerate(function(types) {
			for (type in types) {
				switch (type) {
					case TInst(reference, _):
						var classType = reference.get();
						if (classType.pack.length > 0 && classType.pack[0] == "fried" && isLeftOutOfBuild(classType.name)) {
							var owner = ownerOf(classType.name);
							Context.error('${classType.name} belongs to ${owner.module}: ${owner.backend}, which no platform in project.fried uses. Add it to "modules", or remove its uses.',
								classType.pos);
						}
					default:
				}
			}
		});
	}
	#end

	// For each platform the project declares, the components of the backends it does not use there.
	public static macro function leftOutByPlatform():Expr {
		var entries = [];
		for (platform => chosen in resolved()) {
			var names = [];
			for (module in Reflect.fields(manifest())) {
				var backends = backendsOf(module);
				for (backend in Reflect.fields(backends)) {
					var components:Dynamic = Reflect.field(Reflect.field(backends, backend), "components");
					var isUsed = chosen.get(module) == backend && !isDegraded(module, backend, platform);
					if (!isUsed && Std.isOfType(components, Array)) {
						names = names.concat(components);
					}
				}
			}
			entries.push({platform: platform, names: names});
		}
		return macro $v{entries};
	}

	// The manifest as the editor reads it, with the backend each declared platform uses.
	public static macro function describe():Expr {
		var chosen = [for (platform => modules in resolved()) {platform: platform, modules: [for (module => backend in modules) {module: module, backend: backend}]}];
		return macro {manifest: $v{haxe.Json.stringify(manifest())}, chosen: $v{chosen}};
	}
}
