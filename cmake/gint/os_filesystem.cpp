// gint's file functions call into the OS's own filesystem (BFile), which must
// not run while gint has the hardware: called from inside gint, it can leave
// the calculator to reset itself to factory settings. These replace gint's
// own POSIX file functions with the same ones run back in the OS through a
// world switch.
//
// They replace rather than wrap: gint and fxlibc are built with LTO, and the
// linker's --wrap misses references made from LTO objects. A definition here
// is linked instead of gint's, so the C library's fopen(), fread() and the
// rest, and gint's own creat(), pread(), pwrite() and opendir(), all reach
// these. Each is gint 2.11's own, apart from the switch.

#include <gint/fs.h>
#include <gint/gint.h>

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstdarg>

extern "C"
{
    extern const fs_descriptor_type_t fugue_descriptor_type;

    int fugue_open(const char *path, int flags, mode_t mode);
    int fugue_stat(const char *path, struct stat *status);
    int fugue_mkdir(const char *path, mode_t mode);
    int fugue_rmdir(const char *path);
    int fugue_unlink(const char *path);
    int fugue_rename(const char *from, const char *to);
}

namespace
{
    template <typename Result, typename Call>
    struct Job
    {
        Call *m_call;
        Result m_result;
    };

    template <typename Result, typename Call>
    int runJob(void *data)
    {
        Job<Result, Call> *job = static_cast<Job<Result, Call> *>(data);
        job->m_result = (*job->m_call)();
        return 0;
    }

    template <typename Call>
    auto inOs(Call call) -> decltype(call())
    {
        using Result = decltype(call());
        Job<Result, Call> job = {&call, Result()};
        int (*run)(void *) = runJob<Result, Call>;
        gint_world_switch(GINT_CALL(run, (void *)&job));
        return job.m_result;
    }

    // A directory is read whole when it opens, and anything else open is not
    // a file, so only a file's descriptor reaches BFile afterwards.
    bool reachesBFile(const fs_descriptor_t *descriptor)
    {
        return descriptor->type == &fugue_descriptor_type;
    }
}

extern "C"
{
    int open(const char *path, int flags, ...)
    {
        va_list arguments;
        va_start(arguments, flags);
        mode_t mode = (mode_t)va_arg(arguments, int);
        va_end(arguments);

        return inOs([=] { return fugue_open(path, flags, mode); });
    }

    int close(int fd)
    {
        const fs_descriptor_t *descriptor = fs_get_descriptor(fd);
        if (!descriptor)
        {
            errno = EBADF;
            return -1;
        }

        int result = 0;
        if (descriptor->type->close)
        {
            void *data = descriptor->data;
            auto closeData = descriptor->type->close;
            result = reachesBFile(descriptor) ? inOs([=] { return closeData(data); }) : closeData(data);
        }
        fs_free_descriptor(fd);
        return result;
    }

    ssize_t read(int fd, void *buffer, size_t size)
    {
        const fs_descriptor_t *descriptor = fs_get_descriptor(fd);
        if (!descriptor)
        {
            errno = EBADF;
            return -1;
        }
        if (!descriptor->type->read)
        {
            return 0;
        }

        void *data = descriptor->data;
        auto readData = descriptor->type->read;
        return reachesBFile(descriptor) ? inOs([=] { return readData(data, buffer, size); }) : readData(data, buffer, size);
    }

    ssize_t write(int fd, const void *buffer, size_t size)
    {
        const fs_descriptor_t *descriptor = fs_get_descriptor(fd);
        if (!descriptor)
        {
            errno = EBADF;
            return -1;
        }
        if (!descriptor->type->write)
        {
            return size;
        }

        void *data = descriptor->data;
        auto writeData = descriptor->type->write;
        return reachesBFile(descriptor) ? inOs([=] { return writeData(data, buffer, size); }) : writeData(data, buffer, size);
    }

    off_t lseek(int fd, off_t offset, int whence)
    {
        if (whence != SEEK_SET && whence != SEEK_CUR && whence != SEEK_END)
        {
            errno = EINVAL;
            return -1;
        }

        const fs_descriptor_t *descriptor = fs_get_descriptor(fd);
        if (!descriptor)
        {
            errno = EBADF;
            return -1;
        }
        if (!descriptor->type->lseek)
        {
            return 0;
        }

        void *data = descriptor->data;
        auto seekData = descriptor->type->lseek;
        return reachesBFile(descriptor) ? inOs([=] { return seekData(data, offset, whence); }) : seekData(data, offset, whence);
    }

    int stat(const char *path, struct stat *status)
    {
        return inOs([=] { return fugue_stat(path, status); });
    }

    int mkdir(const char *path, mode_t mode)
    {
        return inOs([=] { return fugue_mkdir(path, mode); });
    }

    int rmdir(const char *path)
    {
        return inOs([=] { return fugue_rmdir(path); });
    }

    int unlink(const char *path)
    {
        return inOs([=] { return fugue_unlink(path); });
    }

    int rename(const char *from, const char *to)
    {
        return inOs([=] { return fugue_rename(from, to); });
    }
}
