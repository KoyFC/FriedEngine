package org.friedengine;

import org.libsdl.app.SDLActivity;

// The game, SDL and the engine are one library, libmain.so, instead of SDL's default of a libSDL2.so beside it.
public class FriedActivity extends SDLActivity
{
    @Override
    protected String[] getLibraries()
    {
        return new String[] {"main"};
    }
}
