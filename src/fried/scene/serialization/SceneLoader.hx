package fried.scene.serialization;

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
		return build(data, renderer);
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

	static function assemble(data:Dynamic, renderer:Renderer):Scene {
		var version = FieldCodec.get(data, "version");
		if (version != FORMAT_VERSION) {
			throw 'The scene file is version $version, and this engine reads version $FORMAT_VERSION.';
		}

		var scene = new Scene(FieldCodec.toText(FieldCodec.get(data, "name"), "name"));
		scene.setView(renderer.width, renderer.height);
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
