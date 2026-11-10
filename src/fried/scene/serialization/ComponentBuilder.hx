package fried.scene.serialization;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;

using Lambda;

private typedef SerializedField = {
	var name:String;
	var codec:String;
	var kind:String;
	var needsContext:Bool;
}

// Runs on every subclass of Component. A class marked @:serializable gets a static describeComponent() that returns how to create, assign and read its fields.
// A public writable var of a supported type is a serialized field, unless it is marked @:noSerialize.
class ComponentBuilder {
	static inline var CODEC = "fried.scene.serialization.FieldCodec";
	static inline var SERIALIZATION = "fried.scene.serialization";

	public static function build():Array<Field> {
		var localClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		if (!localClass.meta.has(":serializable")) {
			return fields;
		}

		var className = localClass.pack.concat([localClass.name]).join(".");
		var serialized = collectFields(fields);
		var source = describeSource(localClass.name, className, serialized, constructorArguments(fields), localClass.pos);

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

	static function collectFields(fields:Array<Field>):Array<SerializedField> {
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
			if (classified != null) {
				classified.name = field.name;
				result.push(classified);
			}
		}
		return result;
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
			case "GameObject": {name: "", codec: "Object", kind: "ObjectRef", needsContext: true};
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

	static function convert(field:SerializedField, owner:String, source:String):String {
		var context = field.needsContext ? ", ctx" : "";
		return '$CODEC.to${field.codec}($CODEC.get(data, "${field.name}"), "$owner.${field.name}"$context)';
	}

	static function describeSource(name:String, className:String, serialized:Array<SerializedField>, arguments:Array<FunctionArg>, position:Position):String {
		var create = new StringBuf();
		var argumentNames = [];
		for (index in 0...arguments.length) {
			var argument = arguments[index];
			var match = serialized.filter(field -> field.name == argument.name)[0];
			var defaultValue = argument.value != null ? ExprTools.toString(argument.value) : null;
			var variable = 'argument$index';
			argumentNames.push(variable);
			if (match == null) {
				if (defaultValue == null && !argument.opt) {
					Context.error('The constructor of $className requires "${argument.name}", which is not a serialized field, so a scene file cannot supply it.', position);
				}
				create.add('var $variable = ${defaultValue != null ? defaultValue : "null"};\n');
				continue;
			}
			var absent = defaultValue != null ? defaultValue : argument.opt ? "null" : 'ctx.usesZeroDefaults ? $CODEC.zero${match.codec}() : $CODEC.missing("$name", "${match.name}")';
			create.add('var $variable = $CODEC.has(data, "${match.name}") ? ${convert(match, name, "data")} : $absent;\n');
		}
		create.add('var instance = new $className(${argumentNames.join(", ")});\n');
		for (field in serialized) {
			if (arguments.exists(argument -> argument.name == field.name)) {
				continue;
			}
			create.add('if ($CODEC.has(data, "${field.name}")) instance.${field.name} = ${convert(field, name, "data")};\n');
		}
		create.add("return instance;\n");

		var apply = new StringBuf();
		apply.add('var self:$className = cast component;\n');
		for (field in serialized) {
			apply.add('if ($CODEC.has(data, "${field.name}")) self.${field.name} = ${convert(field, name, "data")};\n');
		}

		var read = new StringBuf();
		read.add('var self:$className = cast component;\n');
		read.add("return {" + serialized.map(field -> '${field.name}: $CODEC.from${field.codec}(self.${field.name})').join(", ") + "};\n");

		var infos = serialized.map(field -> 'new $SERIALIZATION.FieldInfo("${field.name}", $SERIALIZATION.FieldKind.${field.kind})').join(", ");
		return 'function():$SERIALIZATION.ComponentType {
			return new $SERIALIZATION.ComponentType("$name", [$infos],
				function(data:Dynamic, ctx:$SERIALIZATION.LoadContext):fried.scene.Component {
					${create.toString()}
				},
				function(component:fried.scene.Component, data:Dynamic, ctx:$SERIALIZATION.LoadContext):Void {
					${apply.toString()}
				},
				function(component:fried.scene.Component):Dynamic {
					${read.toString()}
				});
		}';
	}
}
#end
