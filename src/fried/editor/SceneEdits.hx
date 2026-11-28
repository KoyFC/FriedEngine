package fried.editor;

#if fried_editor
import fried.graphics.Renderer;
import fried.scene.Component;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.Transform;
import fried.scene.serialization.ComponentRegistry;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.LoadContext;
import fried.scene.serialization.SceneLoader;

// The editor's changes to a scene that is already built, which the editor player and a running game answer alike.
class SceneEdits {
	// Whether the message is one of those changes, and does it when it is.
	public static function apply(scene:Scene, renderer:Renderer, message:Dynamic):Bool {
		switch (message.type) {
			case "setField":
				setField(scene, renderer, message.id, message.component, message.index, message.field, message.value);
			case "setFields":
				// Many objects at once, each with the fields that changed, which is how a running game's state is shown in the editor's own scene.
				for (entry in (message.objects : Array<Dynamic>)) {
					var object = scene != null ? scene.findById(entry.id) : null;
					if (object == null) {
						continue;
					}
					for (change in (entry.components : Array<Dynamic>)) {
						var component = find(object, change.type, change.index);
						if (component != null) {
							applyFields(scene, renderer, component, entry.id, change.fields);
						}
					}
				}
			case "addObject":
				SceneLoader.addSubtree(require(scene), transformOrRoot(scene, message.parent), message.index, message.object, renderer);
			case "removeObject":
				objectNamed(scene, message.id).destroy();
			case "moveObject":
				SceneLoader.moveSubtree(require(scene), objectNamed(scene, message.id), transformOrRoot(scene, message.parent), message.index);
			case "addComponent":
				SceneLoader.addComponent(require(scene), objectNamed(scene, message.id), message.component, renderer);
			case "removeComponent":
				var target = find(objectNamed(scene, message.id), message.component, message.index);
				if (target == null) {
					throw 'The object ${message.id} has no component ${message.component}.';
				}
				if (Std.isOfType(target, Transform)) {
					throw "The transform of an object cannot be removed.";
				}
				target.gameObject.removeComponent(target);
			case _:
				return false;
		}
		return true;
	}

	public static function require(scene:Scene):Scene {
		if (scene == null) {
			throw "No scene has been loaded.";
		}
		return scene;
	}

	public static function objectNamed(scene:Scene, id:String):GameObject {
		var object = scene != null ? scene.findById(id) : null;
		if (object == null) {
			throw 'The scene has no object "$id".';
		}
		return object;
	}

	// The empty id is the top of the scene.
	public static function transformOrRoot(scene:Scene, id:String):Null<Transform> {
		return id == null || id == "" ? null : objectNamed(scene, id).transform;
	}

	public static function className(component:Component):String {
		return Type.getClassName(Type.getClass(component)).split(".").pop();
	}

	// The component of a class on an object, the transform included, and the index-th one when the object has several of it.
	public static function find(object:GameObject, type:String, index:Null<Int>):Null<Component> {
		var wanted = index == null ? 0 : index;
		var seen = 0;
		for (component in all(object)) {
			if (className(component) == type) {
				if (seen == wanted) {
					return component;
				}
				seen++;
			}
		}
		return null;
	}

	// The transform first, then the components in the order they were added.
	public static function all(object:GameObject):Array<Component> {
		var list:Array<Component> = [object.transform];
		for (component in object.getComponents(Component)) {
			if (component != object.transform) {
				list.push(component);
			}
		}
		return list;
	}

	public static function setField(scene:Scene, renderer:Renderer, id:String, componentType:Null<String>, index:Null<Int>, field:String, value:Dynamic):Void {
		var object = objectNamed(scene, id);
		if (componentType == null || componentType == "") {
			if (field == "name") {
				object.name = FieldCodec.toText(value, "name");
			} else if (field == "active") {
				object.active = FieldCodec.toBool(value, "active");
			} else {
				throw 'An object has no field "$field"; its fields are in its components.';
			}
			return;
		}
		var component = find(object, componentType, index);
		if (component == null) {
			throw 'The object $id has no component $componentType.';
		}
		var data = {};
		Reflect.setField(data, field, value);
		applyFields(scene, renderer, component, id, data);
	}

	static function applyFields(scene:Scene, renderer:Renderer, component:Component, id:String, data:Dynamic):Void {
		var type = ComponentRegistry.get(className(component));
		if (type == null) {
			throw 'A component of the object $id is of a class a scene file cannot name.';
		}
		var context = new LoadContext(renderer);
		context.scene = scene;
		type.apply(component, data, context);
	}
}
#end
