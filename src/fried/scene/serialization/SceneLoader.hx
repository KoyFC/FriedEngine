package fried.scene.serialization;

import fried.Application;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import haxe.Json;

// The fields of a component that name other objects, which can only be assigned once every object of the scene exists.
private typedef PendingReferences = {
	var type:ComponentType;
	var component:Component;
	var data:Dynamic;
}

class SceneLoader {
	public static inline var FORMAT_VERSION:Int = 1;

	// Registers a scene file, under the game's assets, as a scene SceneManager can load.
	public static function register(name:String, assetPath:String, renderer:Renderer):Void {
		SceneManager.register(name, function(context) {
			context.pushScene(renderer, load(assetPath, renderer));
		});
	}

	// Builds the scene of a file under the game's assets for the platform that is running. A game that pushes its own layers uses this instead of register.
	public static function load(assetPath:String, renderer:Renderer):Scene {
		var path = Filesystem.resolveAsset("game", assetPath);
		var data = try {
			Json.parse(Filesystem.readBytes(path).toString());
		} catch (error:Dynamic) {
			throw 'Cannot read the scene file $assetPath: $error';
		}
		return build(data, renderer, Application.platformName);
	}

	// The platform picks which block of the file's "platforms" is applied over the scene, none for null.
	public static function build(data:Dynamic, renderer:Renderer, ?platform:String):Scene {
		var version = FieldCodec.get(data, "version");
		if (version != FORMAT_VERSION) {
			throw 'The scene file is version $version, and this engine reads version $FORMAT_VERSION.';
		}

		var scene = new Scene(FieldCodec.toText(FieldCodec.get(data, "name"), "name"));
		var context = new LoadContext(renderer);
		var references:Array<PendingReferences> = [];
		var objects:Array<Dynamic> = FieldCodec.get(data, "objects");
		if (objects == null) {
			throw "The scene file has no objects list.";
		}
		for (objectData in objects) {
			var object = buildObject(objectData, context, references);
			if (scene.findById(object.id) != null) {
				throw 'The object id "${object.id}" is used twice.';
			}
			scene.add(object);
		}

		context.scene = scene;
		for (pending in references) {
			pending.type.apply(pending.component, pending.data, context);
		}

		var cameraId:Null<String> = FieldCodec.get(data, "camera");
		if (cameraId != null) {
			var cameraObject = scene.findById(cameraId);
			var camera = cameraObject != null ? cameraObject.getComponent(Camera) : null;
			if (camera == null) {
				throw 'The scene camera "$cameraId" is not an object with a Camera component.';
			}
			scene.camera = camera;
		}

		var overrides = FieldCodec.has(data, "platforms") && platform != null ? FieldCodec.get(FieldCodec.get(data, "platforms"), platform) : null;
		if (overrides != null) {
			applyOverrides(overrides, scene, context);
		}
		return scene;
	}

	// The first component of an object whose class has that name, which is how a scene file names a type.
	public static function findComponent(object:GameObject, typeName:String):Null<Component> {
		for (component in object.components) {
			if (Type.getClassName(Type.getClass(component)).split(".").pop() == typeName) {
				return component;
			}
		}
		return null;
	}

	// Each override is an object id, then a component type, then the fields to change. It reaches the first component of that type.
	static function applyOverrides(overrides:Dynamic, scene:Scene, context:LoadContext):Void {
		for (id in Reflect.fields(overrides)) {
			var object = scene.findById(id);
			if (object == null) {
				throw 'A platform override names the object "$id", which the scene does not have.';
			}
			var byType = Reflect.field(overrides, id);
			for (typeName in Reflect.fields(byType)) {
				var type = ComponentRegistry.get(typeName);
				var target = findComponent(object, typeName);
				if (type == null || target == null) {
					throw 'A platform override gives $id a $typeName, which it does not have.';
				}
				type.apply(target, Reflect.field(byType, typeName), context);
			}
		}
	}

	static function buildObject(data:Dynamic, context:LoadContext, references:Array<PendingReferences>):GameObject {
		var id = FieldCodec.toText(FieldCodec.get(data, "id"), "object id");
		if (id == "") {
			throw "An object in the scene file has an empty id.";
		}

		var object = new GameObject(FieldCodec.has(data, "name") ? FieldCodec.toText(FieldCodec.get(data, "name"), '$id.name') : id);
		object.id = id;
		if (FieldCodec.has(data, "active")) {
			object.isActive = FieldCodec.toBool(FieldCodec.get(data, "active"), '$id.active');
		}
		if (FieldCodec.has(data, "priority")) {
			object.priority = FieldCodec.toInt(FieldCodec.get(data, "priority"), '$id.priority');
		}

		var components:Array<Dynamic> = FieldCodec.has(data, "components") ? FieldCodec.get(data, "components") : [];
		for (componentData in components) {
			var typeName = FieldCodec.toText(FieldCodec.get(componentData, "type"), '$id component type');
			var type = ComponentRegistry.get(typeName);
			if (type == null) {
				throw 'The object $id has a component of the unknown type "$typeName".';
			}

			var component:Component;
			if (typeName == "Transform") {
				component = object.transform;
				type.apply(component, componentData, context);
			} else {
				component = type.create(componentData, context);
				object.addComponent(component);
			}
			var referenceData = {};
			var hasReferences = false;
			for (field in type.fields) {
				if (field.kind == ObjectRef && FieldCodec.has(componentData, field.name)) {
					Reflect.setField(referenceData, field.name, FieldCodec.get(componentData, field.name));
					hasReferences = true;
				}
			}
			if (hasReferences) {
				references.push({type: type, component: component, data: referenceData});
			}
			if (FieldCodec.has(componentData, "enabled")) {
				component.enabled = FieldCodec.toBool(FieldCodec.get(componentData, "enabled"), '$id.$typeName.enabled');
			}
		}
		return object;
	}
}
