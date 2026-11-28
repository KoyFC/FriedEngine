package fried.scene.serialization;

import fried.graphics.Renderer;
import fried.scene.SceneManager;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.LoadContext;

// The fields of a component that name other objects, which can only be assigned once every object of the scene exists.
private typedef PendingReferences = {
	var type:ComponentType;
	var component:Component;
	var data:Dynamic;
	var scope:Null<InstanceScope>;
}

// What building the root of an instanced file needs to know: the scope of the file's ids, the fields the instancing entry overrides, and the id the entry gives the root. The overrides name a transform's fields, and the fields of each component by its type.
private typedef InstanceBuild = {
	var inner:InstanceScope;
	var overrides:Dynamic;
	var id:String;
}

class SceneLoader {
	public static inline var FORMAT_VERSION:Int = 3;

	static var entryKeys = ["instance", "id", "children"];

	// The scenes being instanced, outermost first, which is how a scene that ends up instancing itself is found.
	static var instancing:Array<String> = [];

	// Registers a scene file, under the game's assets, as a scene SceneManager can load.
	public static function register(name:String, assetPath:String, renderer:Renderer):Void {
		SceneManager.register(name, function(context) {
			var scene = load(assetPath, renderer);
			context.pushLayer(renderer, new SceneLayer(scene));
			context.onUnload(scene.destroy);
		});
	}

	// Builds the scene of a file under the game's assets for the platform that is running.
	public static function load(assetPath:String, renderer:Renderer):Scene {
		return build(SceneFiles.readPath(assetPath), renderer);
	}

	// Builds the scene with the name the project lists, wherever its data is kept.
	public static function loadNamed(name:String, renderer:Renderer):Scene {
		return build(SceneFiles.read(name), renderer);
	}

	// Components start once every object and reference exists, unless the caller only wants to look at the scene, as the editor does.
	public static function build(data:Dynamic, renderer:Renderer, startComponents:Bool = true):Scene {
		var outer = Component.waitingToStart;
		var waiting:Array<Component> = [];
		Component.waitingToStart = waiting;
		var scene = try {
			assemble(data, renderer);
		} catch (error:Dynamic) {
			Component.waitingToStart = outer;
			throw error;
		}
		Component.waitingToStart = outer;
		if (startComponents) {
			for (component in waiting) {
				component.start();
			}
		}
		return scene;
	}

	static function checkVersion(data:Dynamic, name:String):Void {
		var version = FieldCodec.get(data, "version");
		if (version != FORMAT_VERSION) {
			throw 'The scene file $name is version $version, and this engine reads version $FORMAT_VERSION. Bring it up to date with `fried_import migrate-scenes`: see https://koyfc.github.io/FriedEngine/architecture/scene-files/.';
		}
	}

	static function assemble(data:Dynamic, renderer:Renderer):Scene {
		var sceneName = FieldCodec.toText(FieldCodec.get(data, "name"), "name");
		checkVersion(data, sceneName);

		var scene = new Scene(sceneName);
		scene.setView(renderer.width, renderer.height);
		var context = new LoadContext(renderer);
		var references:Array<PendingReferences> = [];
		var seen = new Map<String, Bool>();
		var objects:Array<Dynamic> = FieldCodec.get(data, "objects");
		if (objects == null) {
			throw "The scene file has no objects list.";
		}
		if (objects.length != 1) {
			throw 'The scene ${scene.name} has ${objects.length} top-level objects, and a scene has exactly one root object. Put them under a new root object: the editor does it when it opens the file.';
		}
		scene.add(buildObject(objects[0], context, references, seen, null));

		context.scene = scene;
		applyReferences(references, context);

		var cameraId:Null<String> = FieldCodec.get(data, "camera");
		if (cameraId != null) {
			var object = scene.findById(cameraId);
			var camera = object != null ? object.getComponent(Camera) : null;
			var camera3D = object != null ? object.getComponent(Camera3D) : null;
			if (camera != null) {
				scene.camera = camera;
			} else if (camera3D != null) {
				scene.camera3D = camera3D;
			} else {
				throw 'The scene camera "$cameraId" is not an object with a Camera or a Camera3D.';
			}
		}
		return scene;
	}

	// Adds a subtree to a scene that exists, under an object or the scene, at a place among its children. Nothing in it is started, which is what the editor wants of a scene it only looks at.
	public static function addSubtree(scene:Scene, parent:Null<Transform>, index:Int, data:Dynamic, renderer:Renderer):Void {
		var outer = Component.waitingToStart;
		Component.waitingToStart = [];
		try {
			var context = new LoadContext(renderer);
			var references:Array<PendingReferences> = [];
			var seen = new Map<String, Bool>();
			var object = buildObject(data, context, references, seen, null);
			for (id in seen.keys()) {
				if (scene.findById(id) != null) {
					throw 'The object id "$id" is already in the scene.';
				}
			}
			object.transform.setParent(parent != null ? parent : scene.root, index);
			context.scene = scene;
			applyReferences(references, context);
		} catch (error:Dynamic) {
			Component.waitingToStart = outer;
			throw error;
		}
		Component.waitingToStart = outer;
	}

	// Moves an object of a scene that exists under another, or to the top of the scene, without starting anything.
	public static function moveSubtree(scene:Scene, object:GameObject, parent:Null<Transform>, index:Int):Void {
		var outer = Component.waitingToStart;
		Component.waitingToStart = [];
		try {
			object.transform.setParent(parent != null ? parent : scene.root, index);
		} catch (error:Dynamic) {
			Component.waitingToStart = outer;
			throw error;
		}
		Component.waitingToStart = outer;
	}

	// Adds a component built from its data to an object of a scene that exists, which the editor does.
	public static function addComponent(scene:Scene, object:GameObject, data:Dynamic, renderer:Renderer):Component {
		var type = typeOf(data, object.id);
		var context = new LoadContext(renderer);
		context.scene = scene;
		var component = type.create(data, context);
		var outer = Component.waitingToStart;
		Component.waitingToStart = [];
		try {
			object.addComponent(component);
		} catch (error:Dynamic) {
			Component.waitingToStart = outer;
			throw error;
		}
		Component.waitingToStart = outer;
		return component;
	}

	static function applyReferences(references:Array<PendingReferences>, context:LoadContext):Void {
		for (pending in references) {
			context.scope = pending.scope;
			pending.type.apply(pending.component, pending.data, context);
		}
		context.scope = null;
	}

	// The root of a scene file that can be instanced, which is the file's only top-level object.
	public static function instanceRoot(data:Dynamic, name:String):Dynamic {
		checkVersion(data, name);
		var objects:Array<Dynamic> = FieldCodec.get(data, "objects");
		if (objects == null || objects.length != 1) {
			throw 'The scene $name has ${objects == null ? 0 : objects.length} top-level objects, and only a scene with exactly one can be instanced.';
		}
		if (FieldCodec.has(objects[0], "instance")) {
			throw 'The root of the scene $name is itself an instance, which is not supported: instance it from the scene that needs it.';
		}
		return objects[0];
	}

	// Builds the root of an instanced scene, starts its components once all of it exists, and leaves it with no parent and no id.
	public static function instantiate(prefab:Prefab, renderer:Renderer):GameObject {
		var outer = Component.waitingToStart;
		var waiting:Array<Component> = [];
		Component.waitingToStart = waiting;
		var object = try {
			var context = new LoadContext(renderer);
			var references:Array<PendingReferences> = [];
			var built = buildInstance(prefab, {}, "", context, references, null);
			applyReferences(references, context);
			built;
		} catch (error:Dynamic) {
			Component.waitingToStart = outer;
			throw error;
		}
		Component.waitingToStart = outer;
		for (pending in waiting) {
			pending.start();
		}
		return object;
	}

	// A scene file instanced as an object: the entry's fields override the file's root, and the file's own objects get ids local to it.
	static function buildInstance(prefab:Prefab, entry:Dynamic, id:String, context:LoadContext, references:Array<PendingReferences>,
			scope:Null<InstanceScope>):GameObject {
		if (instancing.indexOf(prefab.name) >= 0) {
			throw 'The scene ${prefab.name} ends up instancing itself: ${instancing.concat([prefab.name]).join(" > ")}.';
		}
		if (FieldCodec.has(entry, "children")) {
			throw 'The instance $id of ${prefab.name} has children, which an instance cannot have.';
		}
		var merged:Dynamic = {};
		for (field in Reflect.fields(prefab.rootData)) {
			Reflect.setField(merged, field, Reflect.field(prefab.rootData, field));
		}
		if (!FieldCodec.has(merged, "name")) {
			Reflect.setField(merged, "name", Reflect.field(merged, "id"));
		}
		var overrides:Dynamic = {transform: {}, components: {}};
		for (field in Reflect.fields(entry)) {
			if (entryKeys.indexOf(field) < 0) {
				applyEntryField(merged, overrides, field, Reflect.field(entry, field));
			}
		}
		instancing.push(prefab.name);
		var object = try {
			buildObject(merged, context, references, new Map(), scope, {inner: new InstanceScope(), overrides: overrides, id: id});
		} catch (error:Dynamic) {
			instancing.pop();
			throw error;
		}
		instancing.pop();
		return object;
	}

	static function applyEntryField(merged:Dynamic, overrides:Dynamic, field:String, value:Dynamic):Void {
		if (field == "transform") {
			Reflect.setField(merged, field, mergeFields(Reflect.field(merged, field), value));
			Reflect.setField(overrides, "transform", value);
		} else if (field == "components") {
			var list:Array<Dynamic> = Reflect.field(merged, field) == null ? [] : Reflect.field(merged, field).copy();
			for (change in (value : Array<Dynamic>)) {
				var type:String = FieldCodec.get(change, "type");
				var at = indexOfType(list, type);
				if (at >= 0) {
					list[at] = mergeFields(list[at], change);
				} else {
					list.push(change);
				}
				Reflect.setField(Reflect.field(overrides, "components"), type, change);
			}
			Reflect.setField(merged, field, list);
		} else {
			Reflect.setField(merged, field, value);
		}
	}

	static function mergeFields(base:Dynamic, over:Dynamic):Dynamic {
		var result:Dynamic = {};
		if (base != null) {
			for (field in Reflect.fields(base)) {
				Reflect.setField(result, field, Reflect.field(base, field));
			}
		}
		for (field in Reflect.fields(over)) {
			Reflect.setField(result, field, Reflect.field(over, field));
		}
		return result;
	}

	static function indexOfType(list:Array<Dynamic>, type:String):Int {
		for (index in 0...list.length) {
			if (Reflect.field(list[index], "type") == type) {
				return index;
			}
		}
		return -1;
	}

	static function typeOf(data:Dynamic, owner:String):ComponentType {
		var typeName = FieldCodec.toText(FieldCodec.get(data, "type"), '$owner type');
		var type = ComponentRegistry.get(typeName);
		if (type == null) {
			throw 'The object $owner has the unknown component type "$typeName".';
		}
		return type;
	}

	// Children are built and added before their parent joins the scene, so the components start, children first, only once all of it exists.
	static function buildObject(data:Dynamic, context:LoadContext, references:Array<PendingReferences>, seen:Map<String, Bool>, scope:Null<InstanceScope>,
			?instance:InstanceBuild):GameObject {
		var fileId = FieldCodec.toText(FieldCodec.get(data, "id"), "object id");
		if (fileId == "") {
			throw "An object in the scene file has an empty id.";
		}
		if (seen.exists(fileId)) {
			throw 'The object id "$fileId" is used twice.';
		}
		seen.set(fileId, true);

		if (instance == null && FieldCodec.has(data, "instance")) {
			var instanceName = FieldCodec.toText(FieldCodec.get(data, "instance"), '$fileId.instance');
			var built = buildInstance(Prefab.load(instanceName), data, fileId, context, references, scope);
			if (scope != null) {
				scope.objects.set(fileId, built);
			}
			return built;
		}

		var id = instance != null ? instance.id : fileId;
		var pending:Array<{type:ComponentType, component:Component, data:Dynamic, overrides:Dynamic}> = [];

		var transform:Null<Transform> = null;
		if (FieldCodec.has(data, "transform")) {
			var transformData = FieldCodec.get(data, "transform");
			var transformType = typeOf(transformData, fileId);
			transform = Std.downcast(transformType.create(transformData, context), Transform);
			if (transform == null) {
				throw 'The transform of the object $fileId is of the type "${transformType.name}", which is not a transform.';
			}
			pending.push({type: transformType, component: transform, data: transformData, overrides: instance != null ? instance.overrides.transform : null});
		}

		var object = new GameObject(FieldCodec.has(data, "name") ? FieldCodec.toText(FieldCodec.get(data, "name"), '$fileId.name') : id, transform);
		object.id = id;
		if (FieldCodec.has(data, "active")) {
			object.active = FieldCodec.toBool(FieldCodec.get(data, "active"), '$fileId.active');
		}
		object.scopeOwner = scope != null ? scope.root : null;
		var childScope = scope;
		if (instance != null) {
			instance.inner.root = object;
			instance.inner.objects.set(fileId, object);
			object.scopeObjects = instance.inner.objects;
			childScope = instance.inner;
			if (scope != null && id != "") {
				scope.objects.set(id, object);
			}
		} else if (scope != null) {
			scope.objects.set(id, object);
		}

		var componentList:Array<Dynamic> = FieldCodec.has(data, "components") ? FieldCodec.get(data, "components") : [];
		for (componentData in componentList) {
			var typeName:Dynamic = Reflect.field(componentData, "type");
			if (Std.isOfType(typeName, String) && ComponentRegistry.isLeftOut(typeName)) {
				continue;
			}
			var type = typeOf(componentData, fileId);
			var component = type.create(componentData, context);
			object.addComponent(component);
			var overrideFields = instance != null ? Reflect.field(instance.overrides.components, type.name) : null;
			pending.push({type: type, component: component, data: componentData, overrides: overrideFields});
		}

		for (entry in pending) {
			var referenceData = {};
			var outerData = {};
			var hasReferences = false;
			var hasOuterReferences = false;
			for (link in ComponentRegistry.chain(entry.type.name)) {
				for (field in link.fields) {
					if (field.kind == ObjectRef && FieldCodec.has(entry.data, field.name)) {
						// What the entry that instances a file says about an object names an object of the scene around it, and what the file says names its own.
						if (entry.overrides != null && FieldCodec.has(entry.overrides, field.name)) {
							Reflect.setField(outerData, field.name, FieldCodec.get(entry.data, field.name));
							hasOuterReferences = true;
						} else {
							Reflect.setField(referenceData, field.name, FieldCodec.get(entry.data, field.name));
							hasReferences = true;
						}
					}
				}
			}
			if (hasReferences) {
				references.push({type: entry.type, component: entry.component, data: referenceData, scope: childScope});
			}
			if (hasOuterReferences) {
				references.push({type: entry.type, component: entry.component, data: outerData, scope: scope});
			}
		}

		var children:Array<Dynamic> = FieldCodec.has(data, "children") ? FieldCodec.get(data, "children") : [];
		for (childData in children) {
			buildObject(childData, context, references, seen, childScope).transform.setParent(object.transform);
		}
		return object;
	}
}
