package fried.scene.serialization;

import fried.graphics.Renderer;
import fried.io.Filesystem;
import haxe.Json;

class SceneLoader {
	public static inline var FORMAT_VERSION:Int = 1;

	// Registers a scene file, under the game's assets, as a scene SceneManager can load.
	public static function register(name:String, assetPath:String, renderer:Renderer):Void {
		SceneManager.register(name, function(context) {
			var path = Filesystem.resolveAsset("game", assetPath);
			var data = try {
				Json.parse(Filesystem.readBytes(path).toString());
			} catch (error:Dynamic) {
				throw 'Cannot read the scene file $assetPath: $error';
			}
			context.pushScene(renderer, build(data, renderer));
		});
	}

	public static function build(data:Dynamic, renderer:Renderer):Scene {
		var version = FieldCodec.get(data, "version");
		if (version != FORMAT_VERSION) {
			throw 'The scene file is version $version, and this engine reads version $FORMAT_VERSION.';
		}

		var scene = new Scene(FieldCodec.toText(FieldCodec.get(data, "name"), "name"));
		var context = new LoadContext(renderer);
		var objects:Array<Dynamic> = FieldCodec.get(data, "objects");
		if (objects == null) {
			throw "The scene file has no objects list.";
		}
		for (objectData in objects) {
			var object = buildObject(objectData, context);
			if (scene.findById(object.id) != null) {
				throw 'The object id "${object.id}" is used twice.';
			}
			scene.add(object);
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

	static function buildObject(data:Dynamic, context:LoadContext):GameObject {
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
			if (FieldCodec.has(componentData, "enabled")) {
				component.enabled = FieldCodec.toBool(FieldCodec.get(componentData, "enabled"), '$id.$typeName.enabled');
			}
		}
		return object;
	}
}
