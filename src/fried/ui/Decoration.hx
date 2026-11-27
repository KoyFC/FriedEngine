package fried.ui;

import fried.Application;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;

// What a box is drawn with beyond a plain rectangle: rounded corners, a gradient and a shadow, all from the filled rectangles and triangles the draw queue has. A corner is a fan of a few triangles, and a gradient is a few bands of one color each, since the queue fills triangles with one color.
class Decoration {
	static inline var SEGMENTS:Int = 4;
	static inline var BANDS:Int = 8;

	static var rect:Rect = new Rect(0, 0, 0, 0);
	static var points:Array<Float> = [];
	static var colors:Array<Color> = [];

	// The corner of a radius in whole pixels, from the point straight along one side to the point straight along the other, worked out when the radius changes.
	static var arcRadius:Int = -1;
	static var arcX:Array<Int> = [];
	static var arcY:Array<Int> = [];

	// The DS and the calculator draw a box plain: a corner or a gradient there costs far more than a frame can spare.
	public static var isPlain(get, never):Bool;

	static var platformChecked:Bool = false;
	static var isPlainPlatform:Bool = false;

	static function get_isPlain():Bool {
		if (!platformChecked) {
			platformChecked = true;
			isPlainPlatform = Application.platformName == "nds" || Application.platformName == "cg50";
		}
		return isPlainPlatform;
	}

	public static function fill(priority:Int, x:Int, y:Int, width:Int, height:Int, color:Color):Void {
		if (width <= 0 || height <= 0) {
			return;
		}
		rect.x = x;
		rect.y = y;
		rect.width = width;
		rect.height = height;
		DrawQueue.submitFillRect(priority, rect, color);
	}

	// A rectangle with its corners rounded to a radius, which is held to half of the shorter side.
	public static function rounded(priority:Int, x:Int, y:Int, width:Int, height:Int, radius:Int, color:Color):Void {
		var r = radius;
		if (r > width >> 1) {
			r = width >> 1;
		}
		if (r > height >> 1) {
			r = height >> 1;
		}
		if (r <= 0 || isPlain) {
			fill(priority, x, y, width, height, color);
			return;
		}
		fill(priority, x + r, y, width - 2 * r, height, color);
		fill(priority, x, y + r, r, height - 2 * r, color);
		fill(priority, x + width - r, y + r, r, height - 2 * r, color);
		prepareArc(r);
		points.resize(0);
		colors.resize(0);
		corner(x + r, y + r, -1, -1, color);
		corner(x + width - r, y + r, 1, -1, color);
		corner(x + r, y + height - r, -1, 1, color);
		corner(x + width - r, y + height - r, 1, 1, color);
		DrawQueue.submitTriangles(priority, points, colors);
	}

	// A gradient from one color to the other in bands, along the width or along the height.
	public static function gradient(priority:Int, x:Int, y:Int, width:Int, height:Int, isHorizontal:Bool, from:Color, to:Color):Void {
		if (isPlain) {
			fill(priority, x, y, width, height, Color.rgba(mix(from.red, to.red, 8), mix(from.green, to.green, 8), mix(from.blue, to.blue, 8), mix(from.alpha, to.alpha, 8)));
			return;
		}
		var extent = isHorizontal ? width : height;
		for (band in 0...BANDS) {
			var start = (extent * band) >> 3;
			var end = band == BANDS - 1 ? extent : (extent * (band + 1)) >> 3;
			var weight = 2 * band + 1;
			var color = Color.rgba(mix(from.red, to.red, weight), mix(from.green, to.green, weight), mix(from.blue, to.blue, weight), mix(from.alpha, to.alpha, weight));
			if (isHorizontal) {
				fill(priority, x + start, y, end - start, height, color);
			} else {
				fill(priority, x, y + start, width, end - start, color);
			}
		}
	}

	// A channel part of the way from one value to another, in sixteenths.
	static inline function mix(from:Int, to:Int, sixteenths:Int):Int {
		return from + (((to - from) * sixteenths) >> 4);
	}

	static function corner(centerX:Int, centerY:Int, signX:Int, signY:Int, color:Color):Void {
		for (step in 0...SEGMENTS) {
			points.push(centerX);
			points.push(centerY);
			points.push(centerX + signX * arcX[step]);
			points.push(centerY + signY * arcY[step]);
			points.push(centerX + signX * arcX[step + 1]);
			points.push(centerY + signY * arcY[step + 1]);
			colors.push(color);
		}
	}

	static function prepareArc(radius:Int):Void {
		if (radius == arcRadius) {
			return;
		}
		arcRadius = radius;
		arcX = [];
		arcY = [];
		for (step in 0...SEGMENTS + 1) {
			var angle = step * Math.PI / 2 / SEGMENTS;
			arcX.push(Math.round(Math.cos(angle) * radius));
			arcY.push(Math.round(Math.sin(angle) * radius));
		}
	}
}
