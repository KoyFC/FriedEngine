package fried.ui;

// Turns a position in a text into the line and column a person reads it as.
class SourceLines {
	var starts:Array<Int>;

	public function new(text:String) {
		starts = [0];
		for (index in 0...text.length) {
			if (text.charCodeAt(index) == 10) {
				starts.push(index + 1);
			}
		}
	}

	// The line of a position, counting from 1.
	public function line(index:Int):Int {
		var low = 0;
		var high = starts.length - 1;
		while (low < high) {
			var middle = (low + high + 1) >> 1;
			if (starts[middle] <= index) {
				low = middle;
			} else {
				high = middle - 1;
			}
		}
		return low + 1;
	}

	// The column of a position, counting from 1.
	public function column(index:Int):Int {
		return index - starts[line(index) - 1] + 1;
	}
}
