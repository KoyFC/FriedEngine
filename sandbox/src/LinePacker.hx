import fried.graphics.Font;

class LinePacker {
	public static inline var SEPARATOR:String = "   ";

	// A phrase wider than maxWidth still gets a line of its own rather than being split.
	public static function pack(font:Font, phrases:Array<String>, maxWidth:Int):Array<String> {
		var lines:Array<String> = [];
		var line:String = null;
		for (phrase in phrases) {
			var extended = line == null ? phrase : line + SEPARATOR + phrase;
			if (line != null && font.measureWidth(extended) > maxWidth) {
				lines.push(line);
				extended = phrase;
			}
			line = extended;
		}
		if (line != null) {
			lines.push(line);
		}
		return lines;
	}
}
