package fried.scene.serialization;

import fried.io.Filesystem;
#if (fried_editor || fried_text_scenes)
import fried.io.Yaml;
#end

// Where a scene's data comes from. A game ships scenes compiled by tools/fried_import into `scenes/<name>.fscene`; the editor's player, which reads the project's own folder, and any build with -D fried_text_scenes read the YAML or JSON the scene is written in.
class SceneFiles {
	public static inline var COMPILED_SUFFIX:String = ".fscene";
	public static final SOURCE_SUFFIXES:Array<String> = [".scene.yaml", ".scene.json"];

	public static inline function compiledPath(name:String):String {
		return 'scenes/$name$COMPILED_SUFFIX';
	}

	// The name of the scene a source file holds, or null for a file that is not one.
	public static function sceneName(fileName:String):Null<String> {
		for (suffix in SOURCE_SUFFIXES) {
			if (StringTools.endsWith(fileName, suffix)) {
				return fileName.substr(0, fileName.length - suffix.length);
			}
		}
		return null;
	}

	public static function read(name:String):Dynamic {
		#if (fried_editor || fried_text_scenes)
		for (suffix in SOURCE_SUFFIXES) {
			var path = Filesystem.resolveAsset("game", 'scenes/$name$suffix');
			if (Filesystem.exists(path)) {
				return parseText(path, 'scenes/$name$suffix');
			}
		}
		#end
		return readCompiled(compiledPath(name));
	}

	// A scene file of the game's assets by its path, in either form.
	public static function readPath(assetPath:String):Dynamic {
		if (StringTools.endsWith(assetPath, COMPILED_SUFFIX)) {
			return readCompiled(assetPath);
		}
		return parseText(Filesystem.resolveAsset("game", assetPath), assetPath);
	}

	static function readCompiled(assetPath:String):Dynamic {
		var bytes = try {
			Filesystem.readBytes(Filesystem.resolveAsset("game", assetPath));
		} catch (error:Dynamic) {
			throw 'Cannot read the scene file $assetPath: $error';
		}
		return SceneBinary.decode(bytes, assetPath);
	}

	static function parseText(path:String, assetPath:String):Dynamic {
		#if (fried_editor || fried_text_scenes)
		return try {
			Yaml.parse(Filesystem.readBytes(path).toString(), assetPath);
		} catch (error:Dynamic) {
			throw 'Cannot read the scene file $assetPath: $error';
		}
		#else
		throw 'The scene file $assetPath is text, which this build does not read: the assets are compiled into .fscene files.';
		#end
	}
}
