package fried.io;

import haxe.macro.Expr;
#if macro
import haxe.io.Path;
import haxe.macro.Context;

private enum abstract AssetRoot(String) to String {
	var Engine = "engine";
	var Game = "game";
}
#end

class Assets {
	public static macro function engine(relativePath:String):ExprOf<String> {
		return resolve(Engine, relativePath);
	}

	public static macro function game(relativePath:String):ExprOf<String> {
		var caller = Context.getLocalClass();
		if (caller != null && caller.get().pack[0] == "fried") {
			Context.error("Game assets are not reachable from engine code. Engine code may only use fried.Assets.engine().", Context.currentPos());
		}
		return resolve(Game, relativePath);
	}

	#if macro
	static function resolve(root:AssetRoot, relativePath:String):ExprOf<String> {
		if (relativePath == "" || Path.isAbsolute(relativePath) || relativePath.split("/").indexOf("..") != -1) {
			Context.error('Invalid asset path "$relativePath". It must be relative to its own asset root and may not contain "..".', Context.currentPos());
		}

		var sourcePath = Path.join([sourceDirectory(root), relativePath]);
		if (!sys.FileSystem.exists(sourcePath) || sys.FileSystem.isDirectory(sourcePath)) {
			Context.error('Asset not found: $sourcePath', Context.currentPos());
		}

		return macro fried.io.Filesystem.getAssetPath($v{Path.join([(root : String), relativePath])});
	}

	static function sourceDirectory(root:AssetRoot):String {
		return switch (root) {
			case Engine:
				var ownSource = Context.resolvePath("fried/io/Assets.hx");
				Path.join([Path.directory(Path.directory(Path.directory(Path.directory(ownSource)))), "assets"]);
			case Game:
				var overridden = Context.definedValue("fried-game-assets");
				overridden != null ? overridden : "assets";
		};
	}
	#end
}
