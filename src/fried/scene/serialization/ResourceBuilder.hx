package fried.scene.serialization;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class ResourceBuilder {
	static inline var CODEC = "fried.scene.serialization.FieldCodec";
	static inline var FIELDS = "fried.scene.serialization";

	public static function build():Array<Field> {
		var localClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		if (!localClass.meta.has(":serializable") || localClass.isAbstract) {
			return fields;
		}

		var className = localClass.pack.concat([localClass.name]).join(".");
		var category = categoryOf(localClass);
		if (category == null) {
			Context.error("A serializable resource has to be a Mesh or a Material.", localClass.pos);
		}
		var serialized = ComponentBuilder.collectInherited(localClass).concat(ComponentBuilder.collectFields(fields, localClass.pos));

		var create = new StringBuf();
		create.add('var instance = new $className();\n');
		for (field in serialized) {
			create.add('if ($CODEC.has(data, "${field.name}")) instance.${field.name} = ${ComponentBuilder.convert(field, localClass.name)};\n');
		}
		create.add("return instance;\n");

		var read = new StringBuf();
		read.add('var self:$className = cast resource;\n');
		read.add("return {" + serialized.map(field -> '${field.name}: $CODEC.from${field.codec}(self.${field.name})').join(", ") + "};\n");

		var infos = serialized.map(field -> 'new $FIELDS.FieldInfo("${field.name}", $FIELDS.FieldKind.${field.kind})').join(", ");
		var source = 'function():$FIELDS.ResourceType {
			return new $FIELDS.ResourceType("${localClass.name}", "$category", [$infos],
				function(data:Dynamic, ctx:$FIELDS.LoadContext):fried.resources.Resource {
					${create.toString()}
				},
				function(resource:fried.resources.Resource):Dynamic {
					${read.toString()}
				});
		}';
		var describe = Context.parse(source, localClass.pos);
		switch (describe.expr) {
			case EFunction(_, definition):
				fields.push({
					name: "describeResource",
					access: [APublic, AStatic],
					kind: FFun(definition),
					pos: localClass.pos
				});
			case _:
				Context.error("The generated describeResource is not a function.", localClass.pos);
		}
		return fields;
	}

	static function categoryOf(localClass:haxe.macro.Type.ClassType):Null<String> {
		var current:Null<haxe.macro.Type.ClassType> = localClass;
		while (current != null) {
			switch (current.name) {
				case "Mesh":
					return "mesh";
				case "Material":
					return "material";
				case _:
			}
			current = current.superClass != null ? current.superClass.t.get() : null;
		}
		return null;
	}
}
#end
