class Main {
	public static function main():Void {
		var sum = 0;
		for (i in 1...11) {
			sum += i;
		}
		Sys.println("Fried Engine sandbox pipeline OK (1..10 sum = " + sum + ")");

		var result = SdlProof.run(640, 480, 120);
		if (result == 0) {
			Sys.println("Fried Engine SDL2 proof OK (window opened, ran, closed)");
		} else {
			Sys.println("Fried Engine SDL2 proof FAILED (code " + result + ")");
			Sys.exit(result);
		}
	}
}
