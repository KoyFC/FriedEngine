#pragma once

#include "math/real.h"

#include "graphics/display.h"
#include "graphics/mesh.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <type_traits>
#include <vector>

// What the renderers that draw meshes with a GPU work out the same way, in the
// arithmetic MeshPass has on the CPU: the corners of a mesh, each with its
// face's normal, and the matrices that place a mesh in the camera's view.

namespace fried_mesh
{
    constexpr double s_degreesToRadians = 0.017453292519943295;
    constexpr double s_pi = 3.14159265358979323846;

    struct Vertex
    {
        float m_position[3];
        uint8_t m_color[4];
        float m_normal[3];
    };

    struct TexturedVertex
    {
        float m_position[3];
        uint8_t m_color[4];
        float m_normal[3];
        float m_uv[2];
    };

    // Each triangle's three corners, with the normal MeshPass works out from
    // them and the triangle's color as bytes. False if an index is out of range.
    template <typename V>
    inline bool expandInto(const fried_real *vertices, const fried_real *uvs, int vertexCount, const int *indices, const int *argbColors, int triangleCount,
                           std::vector<V> &out)
    {
        out.resize((size_t)triangleCount * 3);
        for (int triangle = 0; triangle < triangleCount; ++triangle)
        {
            int vertexOf[3];
            const fried_real *corner[3];
            for (int index = 0; index < 3; ++index)
            {
                int vertex = indices[triangle * 3 + index];
                if (vertex < 0 || vertex >= vertexCount)
                {
                    return false;
                }
                vertexOf[index] = vertex;
                corner[index] = vertices + vertex * 3;
            }

            double abX = corner[1][0] - corner[0][0];
            double abY = corner[1][1] - corner[0][1];
            double abZ = corner[1][2] - corner[0][2];
            double acX = corner[2][0] - corner[0][0];
            double acY = corner[2][1] - corner[0][1];
            double acZ = corner[2][2] - corner[0][2];
            double normalX = abY * acZ - abZ * acY;
            double normalY = abZ * acX - abX * acZ;
            double normalZ = abX * acY - abY * acX;
            double length = std::sqrt(normalX * normalX + normalY * normalY + normalZ * normalZ);
            if (length > 0.0)
            {
                normalX /= length;
                normalY /= length;
                normalZ /= length;
            }

            uint32_t color = (uint32_t)argbColors[triangle];
            for (int index = 0; index < 3; ++index)
            {
                V &vertex = out[(size_t)triangle * 3 + index];
                vertex.m_position[0] = (float)corner[index][0];
                vertex.m_position[1] = (float)corner[index][1];
                vertex.m_position[2] = (float)corner[index][2];
                vertex.m_color[0] = (uint8_t)(color >> 16);
                vertex.m_color[1] = (uint8_t)(color >> 8);
                vertex.m_color[2] = (uint8_t)color;
                vertex.m_color[3] = (uint8_t)(color >> 24);
                vertex.m_normal[0] = (float)normalX;
                vertex.m_normal[1] = (float)normalY;
                vertex.m_normal[2] = (float)normalZ;
                if constexpr (std::is_same<V, TexturedVertex>::value)
                {
                    vertex.m_uv[0] = uvs ? (float)uvs[vertexOf[index] * 2] : 0.0f;
                    vertex.m_uv[1] = uvs ? (float)uvs[vertexOf[index] * 2 + 1] : 0.0f;
                }
            }
        }
        return true;
    }

    inline bool expand(const fried_real *vertices, int vertexCount, const int *indices, const int *argbColors, int triangleCount, std::vector<Vertex> &out)
    {
        return expandInto<Vertex>(vertices, nullptr, vertexCount, indices, argbColors, triangleCount, out);
    }

    // 3x3 and row-major, the same as Rotation.hx has them.
    inline void rotationMatrix(double x, double y, double z, double *out)
    {
        double sinX = std::sin(x * s_degreesToRadians);
        double cosX = std::cos(x * s_degreesToRadians);
        double sinY = std::sin(y * s_degreesToRadians);
        double cosY = std::cos(y * s_degreesToRadians);
        double sinZ = std::sin(z * s_degreesToRadians);
        double cosZ = std::cos(z * s_degreesToRadians);
        out[0] = cosY * cosZ + sinY * sinX * sinZ;
        out[1] = sinY * sinX * cosZ - cosY * sinZ;
        out[2] = sinY * cosX;
        out[3] = cosX * sinZ;
        out[4] = cosX * cosZ;
        out[5] = -sinX;
        out[6] = cosY * sinX * sinZ - sinY * cosZ;
        out[7] = sinY * sinZ + cosY * sinX * cosZ;
        out[8] = cosY * cosX;
    }

    // A mesh drawn through a view, as the vertex shader takes it. The clip
    // matrix is row-major and maps a corner of the mesh, with a w of 1, to
    // clip space as OpenGL has it: x and y to the right and up, z from -w at
    // the near plane to w at the far one, and w the depth in front of the camera.
    struct Transform
    {
        double m_clip[4][4];
        // A face's normal into the camera's space, row-major, not normalized.
        float m_normal[3][3];
        // Toward the light's source in the camera's space, a unit vector, or zero where there is none.
        float m_light[3];
        float m_ambient;
    };

    // The view is the rectangle of the output the camera's picture fills,
    // which a 2D camera moves and zooms as it does the points of triangles.
    // False where the view or the planes leave nothing to draw.
    inline bool place(const fried_real *placement, bool hasCamera, double zoom, double cameraX, double cameraY, const FriedDisplayLayout &layout,
                      int viewX, int viewY, int viewWidth, int viewHeight, Transform &out)
    {
        double nearPlane = std::max((double)placement[FRIED_MESH_NEAR], 1e-6);
        double farPlane = placement[FRIED_MESH_FAR];
        if (viewWidth <= 0 || viewHeight <= 0 || !(farPlane > nearPlane))
        {
            return false;
        }

        // The camera's turn undone, then the mesh's turn and scale.
        double cameraTurn[9], meshTurn[9];
        rotationMatrix(placement[FRIED_MESH_CAMERA_ROTATION_X], placement[FRIED_MESH_CAMERA_ROTATION_Y], placement[FRIED_MESH_CAMERA_ROTATION_Z], cameraTurn);
        rotationMatrix(placement[FRIED_MESH_ROTATION_X], placement[FRIED_MESH_ROTATION_Y], placement[FRIED_MESH_ROTATION_Z], meshTurn);

        double scale[3] = {placement[FRIED_MESH_SCALE_X], placement[FRIED_MESH_SCALE_Y], placement[FRIED_MESH_SCALE_Z]};
        // A face's normal turns with the cofactor matrix of its transform, which
        // for a turn and a scale is the turn with each axis scaled by the other two.
        double cofactor[3] = {scale[1] * scale[2], scale[0] * scale[2], scale[0] * scale[1]};

        double modelView[3][4];
        for (int row = 0; row < 3; ++row)
        {
            for (int column = 0; column < 3; ++column)
            {
                double turned = cameraTurn[row] * meshTurn[column] + cameraTurn[3 + row] * meshTurn[3 + column] + cameraTurn[6 + row] * meshTurn[6 + column];
                modelView[row][column] = turned * scale[column];
                out.m_normal[row][column] = (float)(turned * cofactor[column]);
            }
        }
        double offsetX = placement[FRIED_MESH_X] - placement[FRIED_MESH_CAMERA_X];
        double offsetY = placement[FRIED_MESH_Y] - placement[FRIED_MESH_CAMERA_Y];
        double offsetZ = placement[FRIED_MESH_Z] - placement[FRIED_MESH_CAMERA_Z];
        for (int row = 0; row < 3; ++row)
        {
            modelView[row][3] = cameraTurn[row] * offsetX + cameraTurn[3 + row] * offsetY + cameraTurn[6 + row] * offsetZ;
        }

        double light[3];
        for (int row = 0; row < 3; ++row)
        {
            light[row] = cameraTurn[row] * placement[FRIED_MESH_LIGHT_X] + cameraTurn[3 + row] * placement[FRIED_MESH_LIGHT_Y] + cameraTurn[6 + row] * placement[FRIED_MESH_LIGHT_Z];
        }
        double lightLength = std::sqrt(light[0] * light[0] + light[1] * light[1] + light[2] * light[2]);
        for (int row = 0; row < 3; ++row)
        {
            out.m_light[row] = lightLength > 0.0 ? (float)(light[row] / lightLength) : 0.0f;
        }
        out.m_ambient = (float)placement[FRIED_MESH_AMBIENT];

        // A point's pixel is its x and y over its depth, times the focal
        // length, from the view's center.
        double zoomOfCamera = hasCamera ? zoom : 1.0;
        double shiftX = hasCamera ? layout.m_width / 2.0 - cameraX * zoom : 0.0;
        double shiftY = hasCamera ? layout.m_height / 2.0 - cameraY * zoom : 0.0;
        double viewportHeight = placement[FRIED_MESH_VIEWPORT_HEIGHT];
        double focal = (viewportHeight / 2.0) / std::tan(placement[FRIED_MESH_FIELD_OF_VIEW] * s_pi / 360.0);
        double focalX = layout.m_scaleX * zoomOfCamera * focal;
        double focalY = layout.m_scaleY * zoomOfCamera * focal;
        double centerX = layout.m_viewportX - viewX + layout.m_scaleX * (zoomOfCamera * (placement[FRIED_MESH_VIEWPORT_X] + placement[FRIED_MESH_VIEWPORT_WIDTH] / 2.0) + shiftX);
        double centerY = layout.m_viewportY - viewY + layout.m_scaleY * (zoomOfCamera * (placement[FRIED_MESH_VIEWPORT_Y] + viewportHeight / 2.0) + shiftY);

        double projection[4][4] = {
            {2.0 * focalX / viewWidth, 0.0, 2.0 * centerX / viewWidth - 1.0, 0.0},
            {0.0, 2.0 * focalY / viewHeight, 1.0 - 2.0 * centerY / viewHeight, 0.0},
            {0.0, 0.0, (farPlane + nearPlane) / (farPlane - nearPlane), -2.0 * farPlane * nearPlane / (farPlane - nearPlane)},
            {0.0, 0.0, 1.0, 0.0}};

        for (int row = 0; row < 4; ++row)
        {
            for (int column = 0; column < 4; ++column)
            {
                double sum = 0.0;
                for (int inner = 0; inner < 3; ++inner)
                {
                    sum += projection[row][inner] * modelView[inner][column];
                }
                if (column == 3)
                {
                    sum += projection[row][3];
                }
                out.m_clip[row][column] = sum;
            }
        }
        return true;
    }
}
