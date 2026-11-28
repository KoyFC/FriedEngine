#pragma once

// The physics2d module's box2d backend (see modules.json). Worlds, bodies and shapes are handles, as everything native is, in meters, radians and kilograms: the pixels of a scene become meters in Haxe. The same functions are in box2d_stub.cpp for the platforms that do not use the backend, where nothing is made and every call does nothing.
extern "C"
{
    int fried_b2_world_create(double gravityX, double gravityY);
    // Destroys the world with its bodies and shapes, whose handles stop being valid.
    void fried_b2_world_destroy(int world);
    void fried_b2_world_step(int world, double seconds, int subSteps);

    // type: 0 static, 1 kinematic, 2 dynamic.
    int fried_b2_body_create(int world, int type, double x, double y, double angle);
    void fried_b2_body_destroy(int body);
    void fried_b2_body_set_transform(int body, double x, double y, double angle);
    // Writes x, y and the angle to out.
    void fried_b2_body_get_transform(int body, double *out);
    void fried_b2_body_set_velocity(int body, double x, double y, double angular);
    // Writes the velocity along x and y and the angular one to out.
    void fried_b2_body_get_velocity(int body, double *out);
    void fried_b2_body_set_options(int body, double gravityScale, int fixedRotation, int bullet, int enabled);
    void fried_b2_body_apply_force(int body, double x, double y);
    void fried_b2_body_apply_impulse(int body, double x, double y);

    // material holds six numbers: density, friction, restitution, isSensor (0 or 1), the layers the shape is on and the layers it meets.
    int fried_b2_shape_box(int body, double halfWidth, double halfHeight, double centerX, double centerY, double angle, const double *material);
    int fried_b2_shape_circle(int body, double radius, double centerX, double centerY, const double *material);
    // A capsule between two points, with the radius around the segment.
    int fried_b2_shape_capsule(int body, double x1, double y1, double x2, double y2, double radius, const double *material);
    // A convex polygon of up to eight points, given as x and y one after the other. Returns -1 when the points make no polygon.
    int fried_b2_shape_polygon(int body, const double *points, int count, const double *material);
    void fried_b2_shape_destroy(int shape);

    // Casts a ray from the origin along the translation, whose length is how far it goes, against the shapes on the layers of mask. Returns the nearest shape it hits, or -1, and writes the point, the normal and the fraction of the translation to out.
    int fried_b2_raycast(int world, double originX, double originY, double translationX, double translationY, unsigned int mask, double *out);
    // Writes the handle of every shape on the layers of mask whose box overlaps the one given, up to max, and returns how many.
    int fried_b2_overlap_box(int world, double left, double top, double right, double bottom, unsigned int mask, int *out, int max);
    // The contacts that began and ended in the last step, and the shapes that entered and left a sensor, as three ints each: the two shapes (the sensor first) and 1 for begun or 0 for ended. Returns how many it wrote, at most max.
    int fried_b2_contact_events(int world, int *out, int max);
}
