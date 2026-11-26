package fried.ui;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using Lambda;

// Runs on every subclass of UIDocument. A class marked @:ui("path/to/file.html") is compiled against that file: the HTML is read while compiling, and what it names has to exist in the class.
//
// An element with an id becomes a field of the class, `play-button` as `playButton`, typed by its tag (UIButton for a button, UIImage for an img, UIElement for the rest) and filled when the document loads. `onclick="startGame"` calls the method `startGame` of the class when the element is clicked. `{{score}}` in a text shows the field `score`, which is rewritten to refresh that text when it is assigned. A name the class lacks, or an id that cannot be a field, is an error at the place in the HTML file. Nothing is looked up by a string from the game's code.
class UIDocumentBuilder {
	static var bindingPattern:EReg = ~/\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}/;
	static var identifierPattern:EReg = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	public static function build():Null<Array<Field>> {
		var cls = Context.getLocalClass().get();
		var meta = cls.meta.extract(":ui");
		if (meta.length == 0) {
			return null;
		}
		var relative = switch (meta[0].params.length == 1 ? meta[0].params[0].expr : null) {
			case EConst(CString(value, _)): value;
			case _: Context.error('@:ui takes the asset path of one HTML file, as in @:ui("ui/menu.html").', meta[0].pos);
		}
		var file = fried.io.Assets.gameSourcePath(relative);
		Context.registerModuleDependency(Context.getLocalModule(), file);
		var text = sys.io.File.getContent(file);
		var xml = try {
			Xml.parse(text);
		} catch (error:Dynamic) {
			Context.error('$relative is not well formed HTML: $error', meta[0].pos);
		}

		var fields = Context.getBuildFields();
		var ids:Array<{id:String, name:String, type:String}> = [];
		var handlers:Array<{name:String, id:String}> = [];
		var bindings:Array<String> = [];
		var ownNames = [for (field in fields) field.name => true];
		collect(xml, file, text, fields, ownNames, ids, handlers, bindings);

		var position = cls.pos;
		var bind = new StringBuf();
		bind.add("super.bindElements();\n");
		for (entry in ids) {
			bind.add('${entry.name} = requireElement("${entry.id}", ${entry.type});\n');
		}
		for (handler in handlers) {
			bind.add('${nameOf(handler.id)}.onClick = ${handler.name};\n');
		}
		for (name in bindings) {
			bind.add('setBinding("$name", Std.string($name));\n');
		}
		for (entry in ids) {
			fields.push({
				name: entry.name,
				access: [APublic],
				kind: FProp("default", "null", TPath(typePath(entry.type))),
				pos: position
			});
		}
		for (name in bindings) {
			rewriteBinding(fields, name, position);
		}
		fields.push({
			name: "sourcePath",
			access: [AOverride],
			kind: FFun({
				args: [],
				ret: macro :Null<String>,
				expr: macro return fried.io.Assets.game($v{relative})
			}),
			pos: position
		});
		fields.push({
			name: "bindElements",
			access: [AOverride],
			kind: FFun({args: [], ret: macro :Void, expr: Context.parse("{\n" + bind.toString() + "}", position)}),
			pos: position
		});
		return fields;
	}

	static function collect(xml:Xml, file:String, text:String, fields:Array<Field>, ownNames:Map<String, Bool>, ids:Array<{id:String, name:String, type:String}>,
			handlers:Array<{name:String, id:String}>, bindings:Array<String>):Void {
		for (child in xml) {
			switch (child.nodeType) {
				case Element:
					var id = child.get("id");
					if (id != null) {
						var name = nameOf(id);
						if (!identifierPattern.match(name)) {
							Context.error('The id "$id" cannot be a field, since "$name" is not a name.', position(file, text, 'id="$id"'));
						}
						if (ids.exists(entry -> entry.name == name)) {
							Context.error('The id "$id" gives the field "$name" a second time.', position(file, text, 'id="$id"'));
						}
						if (ownNames.exists(name)) {
							Context.error('The id "$id" would be the field "$name", which the class already declares.', position(file, text, 'id="$id"'));
						}
						ids.push({id: id, name: name, type: typeOf(child.nodeName.toLowerCase())});
					}
					var handler = child.get("onclick");
					if (handler != null) {
						var at = position(file, text, 'onclick="$handler"');
						if (id == null) {
							Context.error('An element with onclick="$handler" needs an id, so the class can reach it.', at);
						}
						if (!hasMethod(fields, handler)) {
							Context.error('onclick="$handler" names no method with no arguments in this class. Declare "function $handler():Void".', at);
						}
						handlers.push({name: handler, id: id});
					}
					collect(child, file, text, fields, ownNames, ids, handlers, bindings);
				case PCData | CData:
					var remaining = child.nodeValue;
					while (bindingPattern.match(remaining)) {
						var name = bindingPattern.matched(1);
						if (bindings.indexOf(name) < 0) {
							if (!fields.exists(field -> field.name == name && isPlainVar(field))) {
								Context.error('{{$name}} needs a "var $name" with a type in this class.', position(file, text, bindingPattern.matched(0)));
							}
							bindings.push(name);
						}
						remaining = bindingPattern.matchedRight();
					}
				case _:
			}
		}
	}

	// The id as a field name: `play-button` and `play_button` are both playButton.
	static function nameOf(id:String):String {
		var parts = ~/[-_]+/g.split(id);
		var name = parts[0];
		for (index in 1...parts.length) {
			name += parts[index].charAt(0).toUpperCase() + parts[index].substr(1);
		}
		return name;
	}

	static function typeOf(tag:String):String {
		return switch (tag) {
			case "button": "fried.ui.UIButton";
			case "img": "fried.ui.UIImage";
			case _: "fried.ui.UIElement";
		}
	}

	static function typePath(name:String):TypePath {
		var parts = name.split(".");
		return {pack: parts.slice(0, parts.length - 1), name: parts[parts.length - 1]};
	}

	static function hasMethod(fields:Array<Field>, name:String):Bool {
		return fields.exists(field -> field.name == name && switch (field.kind) {
			case FFun(definition): definition.args.length == 0 && (field.access == null || field.access.indexOf(AStatic) < 0);
			case _: false;
		});
	}

	static function isPlainVar(field:Field):Bool {
		return switch (field.kind) {
			case FVar(type, _): type != null && (field.access == null || field.access.indexOf(AStatic) < 0);
			case _: false;
		}
	}

	// A field shown in the HTML refreshes the text when it is assigned.
	static function rewriteBinding(fields:Array<Field>, name:String, position:Position):Void {
		for (index in 0...fields.length) {
			var field = fields[index];
			if (field.name != name) {
				continue;
			}
			switch (field.kind) {
				case FVar(type, value):
					fields[index] = {
						name: field.name,
						doc: field.doc,
						meta: field.meta,
						access: field.access,
						kind: FProp("default", "set", type, value),
						pos: field.pos
					};
					var setter = Context.parse('function set_$name(value:${haxe.macro.ComplexTypeTools.toString(type)}) {
						$name = value;
						setBinding("$name", Std.string(value));
						return value;
					}', position);
					switch (setter.expr) {
						case EFunction(_, definition):
							fields.push({name: "set_" + name, access: [], kind: FFun(definition), pos: position});
						case _:
					}
				case _:
			}
		}
	}

	// Where a text is in the file, so an error points at it. The XML parser gives no positions, so it is found by the text.
	static function position(file:String, text:String, needle:String):Position {
		var index = text.indexOf(needle);
		if (index < 0) {
			index = 0;
		}
		return Context.makePosition({file: file, min: index, max: index + needle.length});
	}
}
#end
