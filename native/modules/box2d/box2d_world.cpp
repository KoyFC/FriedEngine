#include "modules/box2d/box2d_world.h"

#include "handle_pool.h"
#include "last_error.h"

#include <box2d/box2d.h>

#include <cstdint>
#include <vector>

namespace
{
    struct World
    {
        b2WorldId m_id;
    };

    struct Body
    {
        b2BodyId m_id;
        int m_world;
        std::vector<int> m_shapes;
    };

    struct Shape
    {
        b2ShapeId m_id;
        int m_body;
    };

    HandlePool<World> s_worlds;
    HandlePool<Body> s_bodies;
    HandlePool<Shape> s_shapes;

    b2Vec2 vec(double x, double y)
    {
        return {(float)x, (float)y};
    }

    int shapeHandleOf(b2ShapeId id)
    {
        return b2Shape_IsValid(id) ? (int)(intptr_t)b2Shape_GetUserData(id) - 1 : -1;
    }

    // Stores the shape under a handle, which its user data remembers so an event can name it.
    int storeShape(int body, b2ShapeId id)
    {
        Body *owner = s_bodies.get(body);
        if (!owner || !b2Shape_IsValid(id))
        {
            fried_set_last_error("The shape could not be made");
            return -1;
        }
        int handle = s_shapes.store(new Shape{id, body});
        b2Shape_SetUserData(id, (void *)(intptr_t)(handle + 1));
        owner->m_shapes.push_back(handle);
        return handle;
    }

    b2ShapeDef shapeDef(const double *material)
    {
        b2ShapeDef def = b2DefaultShapeDef();
        def.density = (float)material[0];
        def.material.friction = (float)material[1];
        def.material.restitution = (float)material[2];
        def.isSensor = material[3] != 0;
        def.enableSensorEvents = true;
        def.enableContactEvents = true;
        def.filter.categoryBits = (uint64_t)(unsigned int)material[4];
        def.filter.maskBits = (uint64_t)(unsigned int)material[5];
        return def;
    }

    void forgetShape(int handle)
    {
        delete s_shapes.release(handle);
    }

    struct OverlapCollector
    {
        int *m_out;
        int m_max;
        int m_count;
    };

    bool collectOverlap(b2ShapeId id, void *context)
    {
        OverlapCollector *collector = (OverlapCollector *)context;
        int handle = shapeHandleOf(id);
        if (handle >= 0 && collector->m_count < collector->m_max)
        {
            collector->m_out[collector->m_count++] = handle;
        }
        return collector->m_count < collector->m_max;
    }

    void addEvent(int *out, int max, int *count, b2ShapeId first, b2ShapeId second, int isBegin)
    {
        int a = shapeHandleOf(first);
        int b = shapeHandleOf(second);
        if (a >= 0 && b >= 0 && (*count + 1) * 3 <= max)
        {
            out[*count * 3] = a;
            out[*count * 3 + 1] = b;
            out[*count * 3 + 2] = isBegin;
            ++*count;
        }
    }
}

int fried_b2_world_create(double gravityX, double gravityY)
{
    b2WorldDef def = b2DefaultWorldDef();
    def.gravity = vec(gravityX, gravityY);
    return s_worlds.store(new World{b2CreateWorld(&def)});
}

void fried_b2_world_destroy(int world)
{
    World *found = s_worlds.get(world);
    if (!found)
    {
        return;
    }
    for (int handle = 0; handle < s_bodies.capacity(); ++handle)
    {
        Body *body = s_bodies.get(handle);
        if (body && body->m_world == world)
        {
            for (int shape : body->m_shapes)
            {
                forgetShape(shape);
            }
            delete s_bodies.release(handle);
        }
    }
    b2DestroyWorld(found->m_id);
    delete s_worlds.release(world);
}

void fried_b2_world_step(int world, double seconds, int subSteps)
{
    World *found = s_worlds.get(world);
    if (found)
    {
        b2World_Step(found->m_id, (float)seconds, subSteps);
    }
}

int fried_b2_body_create(int world, int type, double x, double y, double angle)
{
    World *owner = s_worlds.get(world);
    if (!owner)
    {
        fried_set_last_error("The physics world does not exist");
        return -1;
    }
    b2BodyDef def = b2DefaultBodyDef();
    def.type = type == 0 ? b2_staticBody : type == 1 ? b2_kinematicBody : b2_dynamicBody;
    def.position = vec(x, y);
    def.rotation = b2MakeRot((float)angle);
    return s_bodies.store(new Body{b2CreateBody(owner->m_id, &def), world, {}});
}

void fried_b2_body_destroy(int body)
{
    Body *found = s_bodies.get(body);
    if (!found)
    {
        return;
    }
    for (int shape : found->m_shapes)
    {
        forgetShape(shape);
    }
    b2DestroyBody(found->m_id);
    delete s_bodies.release(body);
}

void fried_b2_body_set_transform(int body, double x, double y, double angle)
{
    Body *found = s_bodies.get(body);
    if (found)
    {
        b2Body_SetTransform(found->m_id, vec(x, y), b2MakeRot((float)angle));
    }
}

void fried_b2_body_get_transform(int body, double *out)
{
    Body *found = s_bodies.get(body);
    out[0] = out[1] = out[2] = 0;
    if (found)
    {
        b2Vec2 position = b2Body_GetPosition(found->m_id);
        out[0] = position.x;
        out[1] = position.y;
        out[2] = b2Rot_GetAngle(b2Body_GetRotation(found->m_id));
    }
}

void fried_b2_body_set_velocity(int body, double x, double y, double angular)
{
    Body *found = s_bodies.get(body);
    if (found)
    {
        b2Body_SetLinearVelocity(found->m_id, vec(x, y));
        b2Body_SetAngularVelocity(found->m_id, (float)angular);
    }
}

void fried_b2_body_get_velocity(int body, double *out)
{
    Body *found = s_bodies.get(body);
    out[0] = out[1] = out[2] = 0;
    if (found)
    {
        b2Vec2 velocity = b2Body_GetLinearVelocity(found->m_id);
        out[0] = velocity.x;
        out[1] = velocity.y;
        out[2] = b2Body_GetAngularVelocity(found->m_id);
    }
}

void fried_b2_body_set_options(int body, double gravityScale, int fixedRotation, int bullet, int enabled)
{
    Body *found = s_bodies.get(body);
    if (!found)
    {
        return;
    }
    b2Body_SetGravityScale(found->m_id, (float)gravityScale);
    b2Body_SetFixedRotation(found->m_id, fixedRotation != 0);
    b2Body_SetBullet(found->m_id, bullet != 0);
    if (enabled != 0)
    {
        b2Body_Enable(found->m_id);
    }
    else
    {
        b2Body_Disable(found->m_id);
    }
}

void fried_b2_body_apply_force(int body, double x, double y)
{
    Body *found = s_bodies.get(body);
    if (found)
    {
        b2Body_ApplyForceToCenter(found->m_id, vec(x, y), true);
    }
}

void fried_b2_body_apply_impulse(int body, double x, double y)
{
    Body *found = s_bodies.get(body);
    if (found)
    {
        b2Body_ApplyLinearImpulseToCenter(found->m_id, vec(x, y), true);
    }
}

int fried_b2_shape_box(int body, double halfWidth, double halfHeight, double centerX, double centerY, double angle, const double *material)
{
    Body *owner = s_bodies.get(body);
    if (!owner)
    {
        return -1;
    }
    b2ShapeDef def = shapeDef(material);
    b2Polygon box = b2MakeOffsetBox((float)halfWidth, (float)halfHeight, vec(centerX, centerY), b2MakeRot((float)angle));
    return storeShape(body, b2CreatePolygonShape(owner->m_id, &def, &box));
}

int fried_b2_shape_circle(int body, double radius, double centerX, double centerY, const double *material)
{
    Body *owner = s_bodies.get(body);
    if (!owner)
    {
        return -1;
    }
    b2ShapeDef def = shapeDef(material);
    b2Circle circle = {vec(centerX, centerY), (float)radius};
    return storeShape(body, b2CreateCircleShape(owner->m_id, &def, &circle));
}

int fried_b2_shape_capsule(int body, double x1, double y1, double x2, double y2, double radius, const double *material)
{
    Body *owner = s_bodies.get(body);
    if (!owner)
    {
        return -1;
    }
    b2ShapeDef def = shapeDef(material);
    b2Capsule capsule = {vec(x1, y1), vec(x2, y2), (float)radius};
    return storeShape(body, b2CreateCapsuleShape(owner->m_id, &def, &capsule));
}

int fried_b2_shape_polygon(int body, const double *points, int count, const double *material)
{
    Body *owner = s_bodies.get(body);
    if (!owner)
    {
        return -1;
    }
    if (count < 3 || count > B2_MAX_POLYGON_VERTICES)
    {
        fried_set_last_error("A polygon takes between 3 and 8 points");
        return -1;
    }
    b2Vec2 corners[B2_MAX_POLYGON_VERTICES];
    for (int index = 0; index < count; ++index)
    {
        corners[index] = vec(points[index * 2], points[index * 2 + 1]);
    }
    b2Hull hull = b2ComputeHull(corners, count);
    if (hull.count < 3)
    {
        fried_set_last_error("The points of a polygon must be convex and not all on a line");
        return -1;
    }
    b2ShapeDef def = shapeDef(material);
    b2Polygon polygon = b2MakePolygon(&hull, 0.0f);
    return storeShape(body, b2CreatePolygonShape(owner->m_id, &def, &polygon));
}

void fried_b2_shape_destroy(int shape)
{
    Shape *found = s_shapes.get(shape);
    if (!found)
    {
        return;
    }
    Body *owner = s_bodies.get(found->m_body);
    if (owner)
    {
        for (size_t index = 0; index < owner->m_shapes.size(); ++index)
        {
            if (owner->m_shapes[index] == shape)
            {
                owner->m_shapes.erase(owner->m_shapes.begin() + index);
                break;
            }
        }
    }
    if (b2Shape_IsValid(found->m_id))
    {
        b2DestroyShape(found->m_id, true);
    }
    forgetShape(shape);
}

int fried_b2_raycast(int world, double originX, double originY, double translationX, double translationY, unsigned int mask, double *out)
{
    World *found = s_worlds.get(world);
    if (!found)
    {
        return -1;
    }
    b2QueryFilter filter = b2DefaultQueryFilter();
    filter.maskBits = mask;
    b2RayResult result = b2World_CastRayClosest(found->m_id, vec(originX, originY), vec(translationX, translationY), filter);
    if (!result.hit)
    {
        return -1;
    }
    out[0] = result.point.x;
    out[1] = result.point.y;
    out[2] = result.normal.x;
    out[3] = result.normal.y;
    out[4] = result.fraction;
    return shapeHandleOf(result.shapeId);
}

int fried_b2_overlap_box(int world, double left, double top, double right, double bottom, unsigned int mask, int *out, int max)
{
    World *found = s_worlds.get(world);
    if (!found)
    {
        return 0;
    }
    b2QueryFilter filter = b2DefaultQueryFilter();
    filter.maskBits = mask;
    OverlapCollector collector = {out, max, 0};
    b2AABB box = {vec(left, top), vec(right, bottom)};
    b2World_OverlapAABB(found->m_id, box, filter, collectOverlap, &collector);
    return collector.m_count;
}

int fried_b2_contact_events(int world, int *out, int max)
{
    World *found = s_worlds.get(world);
    if (!found)
    {
        return 0;
    }
    int count = 0;
    b2SensorEvents sensors = b2World_GetSensorEvents(found->m_id);
    for (int index = 0; index < sensors.beginCount; ++index)
    {
        addEvent(out, max, &count, sensors.beginEvents[index].sensorShapeId, sensors.beginEvents[index].visitorShapeId, 1);
    }
    for (int index = 0; index < sensors.endCount; ++index)
    {
        addEvent(out, max, &count, sensors.endEvents[index].sensorShapeId, sensors.endEvents[index].visitorShapeId, 0);
    }
    b2ContactEvents contacts = b2World_GetContactEvents(found->m_id);
    for (int index = 0; index < contacts.beginCount; ++index)
    {
        addEvent(out, max, &count, contacts.beginEvents[index].shapeIdA, contacts.beginEvents[index].shapeIdB, 1);
    }
    for (int index = 0; index < contacts.endCount; ++index)
    {
        addEvent(out, max, &count, contacts.endEvents[index].shapeIdA, contacts.endEvents[index].shapeIdB, 0);
    }
    return count;
}
