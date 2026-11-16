package fried.scene.serialization;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ComplexTypeTools;
import haxe.macro.ExprTools;

using Lambda;

private typedef SerializedField = {
	var name:String;
	var codec:String;
	var kind:String;
	var needsContext:Bool;
}

// Runs on every subclass of Node.
//
// A class that declares update, draw or onEvent gets an override of hookFlags that says so, which is how a scene knows which nodes a frame has to call.
//
// A class marked @:serializable also gets a static describeNode() that returns how to create, assign and read its fields. A public writable var of a supported type is a serialized field, unless it is marked @:noSerialize. A field whose type is a node is a reference to another node of the scene, by its id.
class NodeBuilder {
	static inline var CODEC = "fried.scene.serialization.FieldCodec";
	static inline var FIELDS = "fried.scene.serialization";
	static inline var NODES = "fried.scene.serialization";
	static inline var NODE = "fried.scene.Node";
	static var reserved = ["type", "id", "name", "children"];

	public static function build():Array<Field> {
		var localClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		var className = localClass.pack.concat([localClass.name]).join(".");

		if (className != NODE) {
			addHookFlags(localClass, fields);
		}
		if (!localClass.meta.has(":serializable")) {
			return fields;
		}

		var own = collectFields(fields, localClass.pos);
		var serialized = collectInherited(localClass).concat(own);
		var source = describeSource(localClass.name, className, parentName(localClass), own, serialized, constructorArguments(fields), localClass.pos);

		var describe = Context.parse(source, localClass.pos);
		switch (describe.expr) {
			case EFunction(_, definition):
				fields.push({
					name: "describeNode",
					access: [APublic, AStatic],
					kind: FFun(definition),
					pos: localClass.pos
				});
			case _:
				Context.error("The generated describeNode is not a function.", localClass.pos);
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

	static function isNode(type:haxe.macro.Type):Bool {
		return switch (type) {
			case TInst(reference, _):
				var current:Null<haxe.macro.Type.ClassType> = reference.get();
				while (current != null) {
					if (current.pack.concat([current.name]).join(".") == NODE) {
						return true;
					}
					current = current.superClass != null ? current.superClass.t.get() : null;
				}
				false;
			case _:
				false;
		}
	}

	// The fields of every serializable class above this one, so a Sprite's data may set a Node2D's x as well as its own texture.
	static function collectInherited(localClass:haxe.macro.Type.ClassType):Array<SerializedField> {
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
				var classified:Null<SerializedField> = null;
				if (isNode(field.type)) {
					classified = nodeReference();
				} else {
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

	static function collectFields(fields:Array<Field>, position:Position):Array<SerializedField> {
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
			if (classified == null && type != null && isNodeType(type, position)) {
				classified = nodeReference();
			}
			if (classified != null) {
				if (reserved.indexOf(field.name) >= 0) {
					Context.error('The field "${field.name}" is a key of a scene file\'s node, so it cannot also be a serialized field.', position);
				}
				classified.name = field.name;
				result.push(classified);
			}
		}
		return result;
	}

	static function isNodeType(type:ComplexType, position:Position):Bool {
		var resolved = try {
			Context.resolveType(type, position);
		} catch (_:Dynamic) {
			null;
		}
		return resolved != null && isNode(resolved);
	}

	static function nodeReference():SerializedField {
		return {name: "", codec: "Node", kind: "ObjectRef", needsContext: true};
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
			case "Bool": {name: "", codec: "Bool", kind: "Boolean", needsContext: false};
			case "String": {name: "", codec: "Text", kind: "Text", needsContext: false};
			case "Color": {name: "", codec: "Color", kind: "Rgba", needsContext: false};
			case "FlipMode": {name: "", codec: "Flip", kind: "Flip", needsContext: false};
			case "Rect": {name: "", codec: "Rect", kind: "Region", needsContext: false};
			case "Texture": {name: "", codec: "Texture", kind: "TextureRef", needsContext: true};
			case "Font": {name: "", codec: "Font", kind: "FontRef", needsContext: true};
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

	static function convert(field:SerializedField, owner:String):String {
		var context = field.needsContext ? ", ctx" : "";
		var call = '$CODEC.to${field.codec}($CODEC.get(data, "${field.name}"), "$owner.${field.name}"$context)';
		return field.codec == "Node" ? 'cast $call' : call;
	}

	static function describeSource(name:String, className:String, parent:Null<String>, own:Array<SerializedField>, serialized:Array<SerializedField>,
			arguments:Array<FunctionArg>, position:Position):String {
		var create = new StringBuf();
		var argumentNames = [];
		for (index in 0...arguments.length) {
			var argument = arguments[index];
			var match = serialized.filter(field -> field.name == argument.name)[0];
			var defaultValue = argument.value != null ? ExprTools.toString(argument.value) : null;
			var variable = 'argument$index';
			var declared = match != null && match.codec == "Node" && argument.type != null ? ":" + ComplexTypeTools.toString(argument.type) : "";
			argumentNames.push(variable);
			if (match == null) {
				if (defaultValue == null && !argument.opt) {
					Context.error('The constructor of $className requires "${argument.name}", which is not a serialized field, so a scene file cannot supply it.', position);
				}
				create.add('var $variable$declared = ${defaultValue != null ? defaultValue : "null"};\n');
				continue;
			}
			var absent = defaultValue != null ? defaultValue : argument.opt ? "null" : 'ctx.usesZeroDefaults ? ${match.codec == "Node" ? "null" : '$CODEC.zero${match.codec}()'} : $CODEC.missing("$name", "${match.name}")';
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
		apply.add('var self:$className = cast node;\n');
		for (field in serialized) {
			apply.add('if ($CODEC.has(data, "${field.name}")) self.${field.name} = ${convert(field, name)};\n');
		}

		var read = new StringBuf();
		read.add('var self:$className = cast node;\n');
		read.add("return {" + serialized.map(field -> '${field.name}: $CODEC.from${field.codec}(self.${field.name})').join(", ") + "};\n");

		var infos = own.map(field -> 'new $FIELDS.FieldInfo("${field.name}", $FIELDS.FieldKind.${field.kind})').join(", ");
		var parentText = parent == null ? "null" : '"$parent"';
		return 'function():$NODES.NodeType {
			return new $NODES.NodeType("$name", $parentText, [$infos],
				function(data:Dynamic, ctx:$FIELDS.LoadContext):$NODE {
					${create.toString()}
				},
				function(node:$NODE, data:Dynamic, ctx:$FIELDS.LoadContext):Void {
					${apply.toString()}
				},
				function(node:$NODE):Dynamic {
					${read.toString()}
				});
		}';
	}
}
#end
