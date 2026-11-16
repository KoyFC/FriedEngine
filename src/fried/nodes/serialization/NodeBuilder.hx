package fried.nodes.serialization;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

// Runs on every subclass of Node. A class that declares update, draw or onEvent gets an override of hookFlags that says so, which is how a scene knows which nodes a frame has to call.
class NodeBuilder {
	public static function build():Array<Field> {
		var localClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		if (localClass.pack.concat([localClass.name]).join(".") == "fried.nodes.Node") {
			return fields;
		}

		var flags = 0;
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
			return fields;
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
		return fields;
	}
}
#end
