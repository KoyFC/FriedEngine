class Main {
	public static function main():Void {
		var sum = 0;
		for (i in 1...11) {
			sum += i;
		}
		Sys.println("Fried Engine sandbox pipeline OK (1..10 sum = " + sum + ")");
	}
}
