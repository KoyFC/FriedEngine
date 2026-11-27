package fried.ui;

import fried.graphics.Renderer;
import fried.graphics.Texture;

// An <img>, drawn at the size of its texture unless the style gives one. The texture is loaded when the document is first drawn, which is when a renderer is known.
@:allow(fried.ui)
class UIImage extends UIElement {
	// The asset path of the picture.
	public var source(default, null):String;

	var texture:Null<Texture>;
	var isFailed:Bool;

	public function new(source:String, id:Null<String> = null, classes:Array<String> = null) {
		super("img", id, classes);
		kind = UIElement.IMAGE;
		this.source = source;
		isFailed = false;
	}

	// Returns whether it loaded now, which changes the size the layout gives it.
	function load(renderer:Renderer):Bool {
		if (texture != null || isFailed) {
			return false;
		}
		try {
			texture = Texture.from(renderer, source);
		} catch (error:Dynamic) {
			isFailed = true;
			UIDiagnostics.report(source, 0, 0, 'the picture could not be loaded: $error', "check the src of the <img> and that the file is in the assets");
			return false;
		}
		return true;
	}
}
