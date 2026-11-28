#include "modules/box2d/box2d_world.h"

#include "last_error.h"

namespace
{
    bool s_isReported = false;

    void report()
    {
        if (!s_isReported)
        {
            s_isReported = true;
            fried_set_last_error("physics2d: box2d is not used on this platform");
        }
    }
}

int fried_b2_world_create(double, double)
{
    report();
    return -1;
}

void fried_b2_world_destroy(int) {}
void fried_b2_world_step(int, double, int) {}

int fried_b2_body_create(int, int, double, double, double)
{
    report();
    return -1;
}

void fried_b2_body_destroy(int) {}
void fried_b2_body_set_transform(int, double, double, double) {}

void fried_b2_body_get_transform(int, double *out)
{
    out[0] = out[1] = out[2] = 0;
}

void fried_b2_body_set_velocity(int, double, double, double) {}

void fried_b2_body_get_velocity(int, double *out)
{
    out[0] = out[1] = out[2] = 0;
}

void fried_b2_body_set_options(int, double, int, int, int) {}
void fried_b2_body_apply_force(int, double, double) {}
void fried_b2_body_apply_impulse(int, double, double) {}

int fried_b2_shape_box(int, double, double, double, double, double, const double *)
{
    return -1;
}

int fried_b2_shape_circle(int, double, double, double, const double *)
{
    return -1;
}

int fried_b2_shape_capsule(int, double, double, double, double, double, const double *)
{
    return -1;
}

int fried_b2_shape_polygon(int, const double *, int, const double *)
{
    return -1;
}

void fried_b2_shape_destroy(int) {}

int fried_b2_raycast(int, double, double, double, double, unsigned int, double *)
{
    return -1;
}

int fried_b2_overlap_box(int, double, double, double, double, unsigned int, int *, int)
{
    return 0;
}

int fried_b2_contact_events(int, int *, int)
{
    return 0;
}
