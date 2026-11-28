package fried.scene.serialization;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ComplexTypeTools;
import haxe.macro.ExprTools;

using Lambda;

typedef SerializedField = {
	var name:String;
	var codec:String;
	var kind:String;
	var needsContext:Bool;
	@:optional var target:String;
}

// Runs on every subclass of Component.
//
// A class that declares update, draw or onEvent gets an override of hookFlags that says so, which is how a scene knows which components a frame has to call.
//
// A class marked @:serializable also gets a static describeComponent() that returns how to create, assign and read its fields. A public writable var of a supported type is a serialized field, unless it is marked @:noSerialize. A field whose type is a game object or a component is a reference to another object of the scene, by its id.
class ComponentBuilder {
	static inline var CODEC = "fried.scene.serialization.FieldCodec";
	static inline var FIELDS = "fried.scene.serialization";
	static inline var TYPES = "fried.scene.serialization";
	static inline var COMPONENT = "fried.scene.Component";
	static inline var OBJECT = "fried.scene.GameObject";
	static var reserved = ["type"];

	public static function build():Array<Field> {
		var localClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		var className = localClass.pack.concat([localClass.name]).join(".");

		if (className != COMPONENT) {
			addHookFlags(localClass, fields);
		}
		if (!localClass.meta.has(":serializable")) {
			return fields;
		}

		var own = collectFields(fields, localClass.pos);
		var serialized = collectInherited(localClass).concat(own);
		var source = describeSource(localClass.name, className, parentName(localClass), parentPath(localClass), own, serialized, constructorArguments(fields), localClass.pos);

		var describe = Context.parse(source, localClass.pos);
		switch (describe.expr) {
			case EFunction(_, definition):
				fields.push({
					name: "describeComponent",
					access: [APublic, AStatic],
					kind: FFun(definition),
					pos: localClass.pos
				});
			case _:
				Context.error("The generated describeComponent is not a function.", localClass.pos);
		}
		return fields;
	}

	static function addHookFlags(localClass:haxe.macro.Type.ClassType, fields:Array<Field>):Void {
		var flags = 0;
		if (fields.exists(field -> field.name == "hookFlags")) {
			return;
		}
		for (field in fields) {
			if (field.access != null && field.access.indexOf(AStatic) >= 0) {
				continue;
			}
			switch (field.kind) {
				case FFun(_):
					switch (field.name) {
						case "update":
							flags |= 1;
						case "draw":
							flags |= 2;
						case "onEvent":
							flags |= 4;
						case "fixedUpdate":
							flags |= 16;
						case _:
					}
				case _:
			}
		}
		if (flags == 0) {
			return;
		}
		fields.push({
			name: "hookFlags",
			access: [AOverride],
			kind: FFun({
				args: [],
				ret: macro :Int,
				expr: macro return super.hookFlags() | $v{flags}
			}),
			pos: localClass.pos
		});
	}

	// The nearest class above this one that is serializable, which is what the inspector shows under it.
	static function parentName(localClass:haxe.macro.Type.ClassType):Null<String> {
		var parent = localClass.superClass;
		while (parent != null) {
			var parentClass = parent.t.get();
			if (parentClass.meta.has(":serializable")) {
				return parentClass.name;
			}
			parent = parentClass.superClass;
		}
		return null;
	}

	static function parentPath(localClass:haxe.macro.Type.ClassType):Null<String> {
		var parent = localClass.superClass;
		while (parent != null) {
			var parentClass = parent.t.get();
			if (parentClass.meta.has(":serializable")) {
				return parentClass.pack.concat([parentClass.name]).join(".");
			}
			parent = parentClass.superClass;
		}
		return null;
	}

	// The class a reference field points at: a game object, or the component of that class an object has.
	static function referenceTarget(type:haxe.macro.Type):Null<SerializedField> {
		return switch (type) {
			case TInst(reference, _):
				var start = reference.get();
				var startPath = start.pack.concat([start.name]).join(".");
				if (startPath == OBJECT) {
					return {name: "", codec: "Object", kind: "ObjectRef", needsContext: true};
				}
				var current:Null<haxe.macro.Type.ClassType> = start;
				while (current != null) {
					if (current.pack.concat([current.name]).join(".") == COMPONENT) {
						return {name: "", codec: "Component", kind: "ObjectRef", needsContext: true, target: startPath};
					}
					current = current.superClass != null ? current.superClass.t.get() : null;
				}
				null;
			case _:
				null;
		}
	}

	static function isReference(field:SerializedField):Bool {
		return field.codec == "Object" || field.codec == "Component";
	}

	// The fields of every serializable class above this one, so a SpriteRenderer's data may set its priority as well as its own texture.
	public static function collectInherited(localClass:haxe.macro.Type.ClassType):Array<SerializedField> {
		var chain:Array<haxe.macro.Type.ClassType> = [];
		var parent = localClass.superClass;
		while (parent != null) {
			var parentClass = parent.t.get();
			if (!parentClass.meta.has(":serializable")) {
				break;
			}
			chain.unshift(parentClass);
			parent = parentClass.superClass;
		}
		var result = [];
		for (ancestor in chain) {
			for (field in ancestor.fields.get()) {
				if (!field.isPublic || field.meta.has(":noSerialize")) {
					continue;
				}
				var isWritable = switch (field.kind) {
					case FVar(_, AccNormal) | FVar(_, AccCall):
						true;
					case _:
						false;
				}
				if (!isWritable) {
					continue;
				}
				var classified:Null<SerializedField> = referenceTarget(field.type);
				if (classified == null) {
					var typeName = switch (field.type) {
						case TAbstract(reference, _):
							reference.get().name;
						case TInst(reference, _):
							reference.get().name;
						case TEnum(reference, _):
							reference.get().name;
						case _:
							null;
					}
					classified = typeName != null ? classify(TPath({pack: [], name: typeName})) : null;
				}
				if (classified != null) {
					classified.name = field.name;
					result.push(classified);
				}
			}
		}
		return result;
	}

	public static function collectFields(fields:Array<Field>, position:Position):Array<SerializedField> {
		var result = [];
		for (field in fields) {
			if (field.access == null || field.access.indexOf(APublic) < 0 || field.access.indexOf(AStatic) >= 0 || field.access.indexOf(AFinal) >= 0) {
				continue;
			}
			if (field.meta != null && field.meta.exists(entry -> entry.name == ":noSerialize")) {
				continue;
			}
			var type = switch (field.kind) {
				case FVar(type, _):
					type;
				case FProp(_, setter, type, _) if (setter == "default" || setter == "set" || setter == "dynamic"):
					type;
				case _:
					null;
			}
			var classified = type == null ? null : classify(type);
			if (classified == null && type != null) {
				classified = referenceOf(type, position);
			}
			if (classified != null) {
				if (reserved.indexOf(field.name) >= 0) {
					Context.error('The field "${field.name}" is a key of a scene file\'s entry, so it cannot also be a serialized field.', position);
				}
				classified.name = field.name;
				result.push(classified);
			}
		}
		return result;
	}

	static function referenceOf(type:ComplexType, position:Position):Null<SerializedField> {
		var resolved = try {
			Context.resolveType(type, position);
		} catch (_:Dynamic) {
			null;
		}
		return resolved == null ? null : referenceTarget(resolved);
	}

	static function classify(type:ComplexType):Null<SerializedField> {
		var name = switch (type) {
			case TPath(path):
				path.name;
			case _:
				return null;
		}
		return switch (name) {
			case "Int": {name: "", codec: "Int", kind: "Integer", needsContext: false};
			case "Float": {name: "", codec: "Float", kind: "Number", needsContext: false};
			case "Single": {name: "", codec: "Single", kind: "Number", needsContext: false};
			case "Bool": {name: "", codec: "Bool", kind: "Boolean", needsContext: false};
			case "String": {name: "", codec: "Text", kind: "Text", needsContext: false};
			case "Color": {name: "", codec: "Color", kind: "Rgba", needsContext: false};
			case "FlipMode": {name: "", codec: "Flip", kind: "Flip", needsContext: false};
			case "BodyType": {name: "", codec: "BodyType", kind: "Body", needsContext: false};
			case "ShapeType": {name: "", codec: "ShapeType", kind: "Shape", needsContext: false};
			case "PlaneOrientation": {name: "", codec: "Orientation", kind: "Orientation", needsContext: false};
			case "Mesh": {name: "", codec: "Mesh", kind: "MeshRef", needsContext: true};
			case "Material": {name: "", codec: "Material", kind: "MaterialRef", needsContext: true};
			case "Rect": {name: "", codec: "Rect", kind: "Region", needsContext: false};
			case "Texture": {name: "", codec: "Texture", kind: "TextureRef", needsContext: true};
			case "Font": {name: "", codec: "Font", kind: "FontRef", needsContext: true};
			case "HtmlSource": {name: "", codec: "HtmlSource", kind: "HtmlRef", needsContext: false};
			case "StyleSheet": {name: "", codec: "StyleSheet", kind: "StyleSheetRef", needsContext: false};
			case _: null;
		}
	}

	static function constructorArguments(fields:Array<Field>):Array<FunctionArg> {
		for (field in fields) {
			if (field.name == "new") {
				switch (field.kind) {
					case FFun(definition):
						return definition.args;
					case _:
				}
			}
		}
		return [];
	}

	public static function convert(field:SerializedField, owner:String):String {
		var context = field.needsContext ? ", ctx" : "";
		var extra = field.codec == "Component" ? ", " + field.target : "";
		var call = '$CODEC.to${field.codec}($CODEC.get(data, "${field.name}"), "$owner.${field.name}"$context$extra)';
		return field.codec == "Component" ? 'cast $call' : call;
	}

	static function describeSource(name:String, className:String, parent:Null<String>, parentPath:Null<String>, own:Array<SerializedField>, serialized:Array<SerializedField>,
			arguments:Array<FunctionArg>, position:Position):String {
		var create = new StringBuf();
		var argumentNames = [];
		for (index in 0...arguments.length) {
			var argument = arguments[index];
			var match = serialized.filter(field -> field.name == argument.name)[0];
			var defaultValue = argument.value != null ? ExprTools.toString(argument.value) : null;
			var variable = 'argument$index';
			var declared = match != null && isReference(match) && argument.type != null ? ":" + ComplexTypeTools.toString(argument.type) : "";
			argumentNames.push(variable);
			if (match == null) {
				if (defaultValue == null && !argument.opt) {
					Context.error('The constructor of $className requires "${argument.name}", which is not a serialized field, so a scene file cannot supply it.', position);
				}
				create.add('var $variable$declared = ${defaultValue != null ? defaultValue : "null"};\n');
				continue;
			}
			var absent = defaultValue != null ? defaultValue : argument.opt ? "null" : 'ctx.usesZeroDefaults ? ${isReference(match) ? "null" : '$CODEC.zero${match.codec}()'} : $CODEC.missing("$name", "${match.name}")';
			create.add('var $variable$declared = $CODEC.has(data, "${match.name}") ? ${convert(match, name)} : $absent;\n');
		}
		create.add('var instance = new $className(${argumentNames.join(", ")});\n');
		for (field in serialized) {
			if (arguments.exists(argument -> argument.name == field.name)) {
				continue;
			}
			create.add('if ($CODEC.has(data, "${field.name}")) instance.${field.name} = ${convert(field, name)};\n');
		}
		create.add("return instance;\n");

		var apply = new StringBuf();
		apply.add('var self:$className = cast component;\n');
		for (field in serialized) {
			apply.add('if ($CODEC.has(data, "${field.name}")) self.${field.name} = ${convert(field, name)};\n');
		}

		var read = new StringBuf();
		read.add('var self:$className = cast component;\n');
		read.add("return {" + serialized.map(field -> '${field.name}: $CODEC.from${field.codec}(self.${field.name})').join(", ") + "};\n");

		var infos = own.map(field -> 'new $FIELDS.FieldInfo("${field.name}", $FIELDS.FieldKind.${field.kind})').join(", ");
		var parentText = parent == null ? "null" : '"$parent"';
		var parentTypeText = parentPath == null ? "null" : 'function():$TYPES.ComponentType return $parentPath.describeComponent()';
		return 'function():$TYPES.ComponentType {
			return new $TYPES.ComponentType("$name", $parentText, [$infos],
				function(data:Dynamic, ctx:$FIELDS.LoadContext):$COMPONENT {
					${create.toString()}
				},
				function(component:$COMPONENT, data:Dynamic, ctx:$FIELDS.LoadContext):Void {
					${apply.toString()}
				},
				function(component:$COMPONENT):Dynamic {
					${read.toString()}
				}, $parentTypeText);
		}';
	}
}
#end
