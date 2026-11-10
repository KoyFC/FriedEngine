package components;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.scene.Component;

@:serializable
class Box extends Component {
	public var width:Int;
	public var height:Int;
	public var fillColor:Color;
	public var borderColor:Color;

	var rect:Rect;

	public function new(width:Int, height:Int, fillColor:Color, borderColor:Color) {
		super();
		this.width = width;
		this.height = height;
		this.fillColor = fillColor;
		this.borderColor = borderColor;
		rect = new Rect(0, 0, width, height);
	}

	override function draw():Void {
		rect.x = Std.int(transform.x);
		rect.y = Std.int(transform.y);
		rect.width = width;
		rect.height = height;
		DrawQueue.submitFillRect(gameObject.priority, rect, fillColor);
		DrawQueue.submitRect(gameObject.priority, rect, borderColor);
	}
}
