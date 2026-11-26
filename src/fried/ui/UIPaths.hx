package fried.ui;

import fried.io.Filesystem;
import haxe.io.Path;

class UIPaths {
	// The asset a document or a sheet names. A path starting with `engine:` or `game:` is in that asset root, and any other is relative to the directory of the file that names it.
	public static function resolve(basePath:String, url:String):String {
		for (root in ["engine", "game"]) {
			if (StringTools.startsWith(url, root + ":")) {
				return Filesystem.resolveAsset(root, url.substr(root.length + 1));
			}
		}
		return Path.normalize(Path.join([Path.directory(basePath), url]));
	}
}
