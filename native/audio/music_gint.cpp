#include "audio/music.h"

#include "handle_pool.h"
#include "last_error.h"

#include <sys/stat.h>

// The calculator has no audio output. Music is loaded and played the same as
// anywhere else, one track at a time, only silently, and with no length to
// reach the end of, so a track plays until it is stopped.

namespace
{
    struct Music
    {
    };

    HandlePool<Music> s_music;
    int s_musicIdOnStream = -1;
    bool s_paused = false;
    double s_volume = 1.0;

    bool isOnStream(int musicId)
    {
        return musicId >= 0 && musicId == s_musicIdOnStream;
    }
}

int fried_music_load(const char *path)
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

    return s_music.store(new Music{});
}

void fried_music_destroy(int musicId)
{
    fried_music_stop(musicId);
    delete s_music.release(musicId);
}

void fried_music_play(int musicId, int)
{
    if (!s_music.get(musicId))
    {
        return;
    }
    s_musicIdOnStream = musicId;
    s_paused = false;
}

void fried_music_pause(int musicId)
{
    if (isOnStream(musicId))
    {
        s_paused = true;
    }
}

void fried_music_resume(int musicId)
{
    if (isOnStream(musicId))
    {
        s_paused = false;
    }
}

void fried_music_stop(int musicId)
{
    if (!isOnStream(musicId))
    {
        return;
    }
    s_musicIdOnStream = -1;
    s_paused = false;
}

bool fried_music_is_playing(int musicId)
{
    return isOnStream(musicId) && !s_paused;
}

bool fried_music_is_paused(int musicId)
{
    return isOnStream(musicId) && s_paused;
}

void fried_music_set_volume(double volume)
{
    s_volume = volume < 0.0 ? 0.0 : volume > 1.0 ? 1.0 : volume;
}

double fried_music_get_volume()
{
    return s_volume;
}
