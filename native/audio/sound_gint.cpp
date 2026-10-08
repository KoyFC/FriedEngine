#include "audio/sound.h"

#include "handle_pool.h"
#include "last_error.h"

#include <sys/stat.h>

// The calculator has no audio output. A sound still has to exist where a game
// loaded it, so a missing file fails the same as anywhere else, and keeps the
// volume it is given, but playing it finishes at once without a sound.

namespace
{
    struct Sound
    {
        double m_volume;
    };

    HandlePool<Sound> s_sounds;
}

int fried_sound_load(const char *path)
{
    if (!path)
    {
        fried_set_last_error("No path given");
        return -1;
    }

    struct stat status;
    if (stat(path, &status) != 0)
    {
        fried_set_last_error("No such file");
        return -1;
    }

    return s_sounds.store(new Sound{1.0});
}

void fried_sound_destroy(int soundId)
{
    delete s_sounds.release(soundId);
}

void fried_sound_play(int, int)
{
}

void fried_sound_stop(int)
{
}

bool fried_sound_is_playing(int)
{
    return false;
}

void fried_sound_set_volume(int soundId, double volume)
{
    Sound *sound = s_sounds.get(soundId);
    if (!sound)
    {
        return;
    }
    sound->m_volume = volume < 0.0 ? 0.0 : volume > 1.0 ? 1.0 : volume;
}

double fried_sound_get_volume(int soundId)
{
    Sound *sound = s_sounds.get(soundId);
    return sound ? sound->m_volume : 0.0;
}
