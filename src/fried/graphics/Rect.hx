package fried.graphics;

class Rect {
	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;

	public function new(x:Int, y:Int, width:Int, height:Int) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public function destroy():Void {
		x = 0;
		y = 0;
		width = 0;
		height = 0;
	}
}
