package components;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.scene.Renderer2D;
import fried.scene.Transform2D;

@:serializable
class Box extends Renderer2D {
	public var width:Int;
	public var height:Int;
	public var fillColor:Color;
	public var borderColor:Color;

	var rect:Rect;
	var place:Transform2D;

	public function new(width:Int, height:Int, fillColor:Color, borderColor:Color) {
		super();
		this.width = width;
		this.height = height;
		this.fillColor = fillColor;
		this.borderColor = borderColor;
		rect = new Rect(0, 0, width, height);
	}

	override function awake():Void {
		place = need(Transform2D);
	}

	override function draw():Void {
		rect.x = Std.int(place.worldX);
		rect.y = Std.int(place.worldY);
		rect.width = width;
		rect.height = height;
		DrawQueue.submitFillRect(priority, rect, fillColor);
		DrawQueue.submitRect(priority, rect, borderColor);
	}
}
