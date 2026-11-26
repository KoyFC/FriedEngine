package fried.graphics;

class TextLayout {
	// Breaks the text between words into lines no wider than maxWidth, and a newline always ends a line. A word wider than maxWidth gets a line of its own.
	public static function breakLines(font:Font, text:String, maxWidth:Int):Array<String> {
		var result = [];
		for (paragraph in text.split("\n")) {
			var line:Null<String> = null;
			for (word in paragraph.split(" ")) {
				if (line == null) {
					line = word;
				} else if (font.measureWidth(line + " " + word) <= maxWidth) {
					line += " " + word;
				} else {
					result.push(line);
					line = word;
				}
			}
			result.push(line == null ? "" : line);
		}
		return result;
	}
}
