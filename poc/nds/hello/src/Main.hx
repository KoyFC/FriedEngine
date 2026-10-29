import cpp.vm.Gc;

class Point {
	public var x:Float;
	public var y:Float;
	public var name:String;

	public function new(x:Float, y:Float, name:String) {
		this.x = x;
		this.y = y;
		this.name = name;
	}
}

class Main {
	static function print(text:String):Void {
		Native.print(text);
	}

	static function gcReport(label:String):Void {
		Native.report(label);
		print(' gc use ${Std.int(Gc.memInfo(Gc.MEM_INFO_USAGE) / 1024)}'
			+ ' cur ${Std.int(Gc.memInfo(Gc.MEM_INFO_CURRENT) / 1024)}'
			+ ' rsv ${Std.int(Gc.memInfo(Gc.MEM_INFO_RESERVED) / 1024)} K');
	}

	static function timed(label:String, body:Void->Void):Void {
		var start = Native.milliseconds();
		body();
		var elapsed = Native.milliseconds() - start;
		print('$label: ${Std.int(elapsed * 1000)} us');
	}

	static function main() {
		Native.init();
		print("Haxe/hxcpp on NDS");
		gcReport("boot");

		var text = "";
		timed("200 str +=", () -> {
			for (i in 0...200) {
				text += Std.string(i);
			}
		});
		
		var numbers:Array<Int> = [];
		timed("1000 push", () -> {
			for (i in 0...1000) {
				numbers.push(i * 3);
			}
		});

		var points:Array<Point> = [];
		timed("200 new obj", () -> {
			for (i in 0...200) {
				points.push(new Point(i * 0.5, i * 1.5, "p" + i));
			}
		});

		var byName = new Map<String, Int>();
		timed("100 map set", () -> {
			for (i in 0...100) {
				byName.set("k" + i, i);
			}
		});

		var intSum = 0;
		timed("10k int mad", () -> {
			for (i in 0...10000) {
				intSum = intSum * 3 + i;
			}
		});

		var floatSum = 0.0;
		timed("10k flt mad", () -> {
			for (i in 0...10000) {
				floatSum = floatSum * 0.5 + i;
			}
		});

		var trig = 0.0;
		timed("1000 sin", () -> {
			for (i in 0...1000) {
				trig += Math.sin(i * 0.01);
			}
		});

		gcReport("tests");

		#if !skip_major_gc
		timed("major gc", () -> Gc.run(true));
		#end
		gcReport("gc");

		print('ok ${text.length} ${numbers[999]} ${points[199].name} ${byName.get("k99")} ${Std.int(floatSum)} ${Std.int(trig)} ${intSum & 0xff}');
		print("done");

		while (true) {
			Native.waitForVblank();
		}
	}
}
