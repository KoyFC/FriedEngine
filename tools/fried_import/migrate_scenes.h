#pragma once

namespace fried_import
{
    // Rewrites the version 2 scene files of a project, which are trees of nodes, as version 3 files, which are objects with a transform and components. The originals are kept under .fried/v2-backup.
    int runMigrateScenes(const char *projectDirectory);
}
