package fried.io;

import fried.NativeError;

import fried.Project;

class UserData {
	public static var path(default, null):String;

	public static function getPath(relativePath:String):String {
		if (relativePath == "" || haxe.io.Path.isAbsolute(relativePath) || relativePath.split("/").indexOf("..") != -1) {
			throw 'Invalid user data path "$relativePath". It must be relative to the user data root and may not contain "..".';
		}
		return path + relativePath;
	}

	public static function exists(relativePath:String):Bool {
		return sys.FileSystem.exists(getPath(relativePath));
	}

	public static function read(relativePath:String):String {
		return sys.io.File.getContent(getPath(relativePath));
	}

	public static function write(relativePath:String, contents:String):Void {
		var fullPath = getPath(relativePath);
		var directory = haxe.io.Path.directory(fullPath);
		if (!sys.FileSystem.exists(directory)) {
			sys.FileSystem.createDirectory(directory);
		}
		sys.io.File.saveContent(fullPath, contents);
	}

	@:allow(fried.Application)
	static function init():Void {
		UserDataNative.init(Project.organization(), Project.name());
		path = UserDataNative.getPath();
		if (path == "") {
			throw NativeError.describe("Failed to resolve the user data path");
		}
	}
}

@:include("platform/filesystem.h")
private extern class UserDataNative {
	@:native("fried_filesystem_init_user_data")
	static function init(organization:cpp.ConstCharStar, name:cpp.ConstCharStar):Void;

	@:native("fried_filesystem_get_user_data_path")
	static function getPath():cpp.ConstCharStar;
}
