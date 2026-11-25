// SDLActivity runs the game by calling SDL_main in libmain.so, on a thread of its own. hxcpp built for Android declares hxcpp_main() in place of main(): it boots the runtime, runs the game and logs an uncaught exception.
extern "C" void hxcpp_main();

extern "C" __attribute__((visibility("default"))) int SDL_main(int, char **)
{
    hxcpp_main();
    return 0;
}
