package fried.ui;

// What the UI drops, repairs or does not support, said once each with where it was and how to fix it.
class UIDiagnostics {
	// Takes the lines instead of the log, for a check that reads them.
	public static var sink:Null<String->Void>;

	static var seen:Map<String, Bool> = new Map();

	// A line of zero is a message about a whole file or an element, which an HTML file cannot place better than by its path.
	public static function report(path:String, line:Int, column:Int, message:String, fix:String):Void {
		var text = line > 0 ? '$path:$line:$column: $message (fix: $fix)' : '$path: $message (fix: $fix)';
		if (seen.exists(text)) {
			return;
		}
		seen.set(text, true);
		if (sink != null) {
			sink(text);
		} else {
			Log.warn(text);
		}
	}

	public static function forget():Void {
		seen = new Map();
	}
}
