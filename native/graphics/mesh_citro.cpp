#include "graphics/mesh.h"
#include "graphics/mesh_citro.h"

#include "graphics/mesh_geometry.h"
#include "graphics/renderer.h"

#include <3ds.h>
#include <citro2d.h>

#include "mesh_citro_shbin.h"

#include <cstring>
#include <vector>

// Meshes drawn by the 3DS's GPU, between citro2d's own draws: the shader
// turns and lights each face as MeshPass does, the screen's depth buffer
// sorts them, and citro2d's state is put back when something else is about to
// draw. citro2d draws every 2D object at one depth and keeps whatever depth
// the last draw left, so the depth buffer is written to zero, which anything
// at that depth passes over, before and after a run of meshes.

namespace
{
    using Vertex = fried_mesh::Vertex;

    struct Mesh
    {
        Vertex *m_vertices;
        int m_vertexCount;
    };

    constexpr int s_attributeCount = 3;
    constexpr int s_cornersOfClearQuad = 6;

    std::vector<Mesh> s_meshes;
    std::vector<int> s_freeMeshes;

    DVLB_s *s_binary = nullptr;
    shaderProgram_s s_program;
    C3D_AttrInfo s_attrInfo;
    C3D_BufInfo s_bufInfo;
    Vertex *s_clearQuad = nullptr;
    int s_clipUniform = -1;
    int s_normalUniform = -1;
    int s_lightUniform = -1;
    int s_ambientUniform = -1;

    bool s_isReady = false;
    bool s_isInMeshMode = false;
    bool s_isViewSet = false;
    double s_lastView[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 3];

    bool prepareShader()
    {
        if (s_isReady)
        {
            return true;
        }

        s_clearQuad = static_cast<Vertex *>(linearAlloc(sizeof(Vertex) * s_cornersOfClearQuad));
        if (!s_clearQuad)
        {
            return false;
        }
        static const float corners[s_cornersOfClearQuad][2] = {{-1, -1}, {1, -1}, {1, 1}, {-1, -1}, {1, 1}, {-1, 1}};
        std::memset(s_clearQuad, 0, sizeof(Vertex) * s_cornersOfClearQuad);
        for (int corner = 0; corner < s_cornersOfClearQuad; ++corner)
        {
            s_clearQuad[corner].m_position[0] = corners[corner][0];
            s_clearQuad[corner].m_position[1] = corners[corner][1];
        }
        GSPGPU_FlushDataCache(s_clearQuad, sizeof(Vertex) * s_cornersOfClearQuad);

        s_binary = DVLB_ParseFile((u32 *)mesh_citro_shbin, mesh_citro_shbin_size);
        if (!s_binary)
        {
            linearFree(s_clearQuad);
            s_clearQuad = nullptr;
            return false;
        }
        shaderProgramInit(&s_program);
        shaderProgramSetVsh(&s_program, &s_binary->DVLE[0]);
        s_clipUniform = shaderInstanceGetUniformLocation(s_program.vertexShader, "clip");
        s_normalUniform = shaderInstanceGetUniformLocation(s_program.vertexShader, "normalMatrix");
        s_lightUniform = shaderInstanceGetUniformLocation(s_program.vertexShader, "light");
        s_ambientUniform = shaderInstanceGetUniformLocation(s_program.vertexShader, "ambient");

        AttrInfo_Init(&s_attrInfo);
        AttrInfo_AddLoader(&s_attrInfo, 0, GPU_FLOAT, 3);
        AttrInfo_AddLoader(&s_attrInfo, 1, GPU_UNSIGNED_BYTE, 4);
        AttrInfo_AddLoader(&s_attrInfo, 2, GPU_FLOAT, 3);
        s_isReady = true;
        return true;
    }

    void setClip(const float rows[4][4])
    {
        for (int row = 0; row < 4; ++row)
        {
            C3D_FVUnifSet(GPU_VERTEX_SHADER, s_clipUniform + row, rows[row][0], rows[row][1], rows[row][2], rows[row][3]);
        }
    }

    void setNormalMatrix(const float rows[3][3])
    {
        for (int row = 0; row < 3; ++row)
        {
            C3D_FVUnifSet(GPU_VERTEX_SHADER, s_normalUniform + row, rows[row][0], rows[row][1], rows[row][2], 0.0f);
        }
    }

    void bindVertices(const Vertex *vertices)
    {
        BufInfo_Init(&s_bufInfo);
        BufInfo_Add(&s_bufInfo, vertices, sizeof(Vertex), s_attributeCount, 0x210);
        C3D_SetBufInfo(&s_bufInfo);
    }

    // Writes zero to the depth buffer over the whole screen and nothing to the colors.
    void clearDepth()
    {
        static const float identity[4][4] = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 1}};
        static const float normals[3][3] = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
        C3D_CullFace(GPU_CULL_NONE);
        C3D_DepthTest(true, GPU_ALWAYS, GPU_WRITE_DEPTH);
        setClip(identity);
        setNormalMatrix(normals);
        C3D_FVUnifSet(GPU_VERTEX_SHADER, s_lightUniform, 0.0f, 0.0f, 0.0f, 0.0f);
        C3D_FVUnifSet(GPU_VERTEX_SHADER, s_ambientUniform, 1.0f, 1.0f, 1.0f, 1.0f);
        bindVertices(s_clearQuad);
        C3D_DrawArrays(GPU_TRIANGLES, 0, s_cornersOfClearQuad);
    }

    void enterMeshMode()
    {
        C2D_Flush();
        C3D_BindProgram(&s_program);
        C3D_SetAttrInfo(&s_attrInfo);

        // The colors the shader gives, and nothing from any texture.
        for (int stage = 0; stage < 6; ++stage)
        {
            C3D_TexEnv *env = C3D_GetTexEnv(stage);
            C3D_TexEnvInit(env);
        }
        C3D_TexEnv *first = C3D_GetTexEnv(0);
        C3D_TexEnvSrc(first, C3D_Both, GPU_PRIMARY_COLOR, (GPU_TEVSRC)0, (GPU_TEVSRC)0);
        C3D_TexEnvFunc(first, C3D_Both, GPU_REPLACE);

        C3D_DepthMap(true, -1.0f, 0.0f);
        clearDepth();
        C3D_CullFace(GPU_CULL_FRONT_CCW);
        C3D_DepthTest(true, GPU_GREATER, GPU_WRITE_ALL);

        s_isViewSet = false;
        s_isInMeshMode = true;
    }
}

void fried_mesh_citro_leave()
{
    if (!s_isInMeshMode)
    {
        return;
    }
    s_isInMeshMode = false;
    clearDepth();
    C2D_Prepare();
}

void fried_mesh_citro_stop()
{
    fried_mesh_citro_leave();
    if (!s_isReady)
    {
        return;
    }
    shaderProgramFree(&s_program);
    DVLB_Free(s_binary);
    linearFree(s_clearQuad);
    s_binary = nullptr;
    s_clearQuad = nullptr;
    s_isReady = false;
}

void fried_mesh_citro_draw(int meshId, const double *placement, bool hasCamera, double zoom, double cameraX, double cameraY,
                           const FriedDisplayLayout &layout, int outputWidth, int outputHeight)
{
    if (!placement || meshId < 0 || meshId >= (int)s_meshes.size() || !s_meshes[meshId].m_vertices || !prepareShader())
    {
        return;
    }

    fried_mesh::Transform transform;
    if (!fried_mesh::place(placement, hasCamera, zoom, cameraX, cameraY, layout, 0, 0, outputWidth, outputHeight, transform))
    {
        return;
    }

    if (!s_isInMeshMode)
    {
        enterMeshMode();
    }

    // The light is set again whenever the view changes.
    double view[sizeof(s_lastView) / sizeof(double)];
    std::memcpy(view, placement + FRIED_MESH_CAMERA_X, (FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X) * sizeof(double));
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X] = hasCamera ? zoom : 0.0;
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 1] = hasCamera ? cameraX : 0.0;
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 2] = hasCamera ? cameraY : 0.0;
    if (!s_isViewSet || std::memcmp(view, s_lastView, sizeof(view)) != 0)
    {
        if (s_isViewSet)
        {
            clearDepth();
            C3D_CullFace(GPU_CULL_FRONT_CCW);
            C3D_DepthTest(true, GPU_GREATER, GPU_WRITE_ALL);
        }
        C3D_FVUnifSet(GPU_VERTEX_SHADER, s_lightUniform, transform.m_light[0], transform.m_light[1], transform.m_light[2], 0.0f);
        C3D_FVUnifSet(GPU_VERTEX_SHADER, s_ambientUniform, transform.m_ambient, transform.m_ambient, transform.m_ambient, transform.m_ambient);
        std::memcpy(s_lastView, view, sizeof(view));
        s_isViewSet = true;
    }

    // The screen is mounted a quarter turn, so what is across the picture is
    // up and down on the GPU's.
    float clip[4][4];
    for (int column = 0; column < 4; ++column)
    {
        clip[0][column] = (float)transform.m_clip[1][column];
        clip[1][column] = (float)-transform.m_clip[0][column];
        clip[2][column] = (float)((transform.m_clip[2][column] - transform.m_clip[3][column]) / 2.0);
        clip[3][column] = (float)transform.m_clip[3][column];
    }
    setClip(clip);
    setNormalMatrix(transform.m_normal);

    const Mesh &mesh = s_meshes[meshId];
    bindVertices(mesh.m_vertices);
    C3D_DrawArrays(GPU_TRIANGLES, 0, mesh.m_vertexCount);
}

int fried_mesh_create(const double *vertices, int vertexCount, const int *indices, const int *argbColors, int triangleCount)
{
    if (!vertices || !indices || !argbColors || triangleCount <= 0)
    {
        return -1;
    }

    std::vector<Vertex> expanded;
    if (!fried_mesh::expand(vertices, vertexCount, indices, argbColors, triangleCount, expanded))
    {
        return -1;
    }
    size_t size = expanded.size() * sizeof(Vertex);
    Vertex *linear = static_cast<Vertex *>(linearAlloc(size));
    if (!linear)
    {
        return -1;
    }
    std::memcpy(linear, expanded.data(), size);
    GSPGPU_FlushDataCache(linear, size);

    int id;
    if (!s_freeMeshes.empty())
    {
        id = s_freeMeshes.back();
        s_freeMeshes.pop_back();
    }
    else
    {
        id = (int)s_meshes.size();
        s_meshes.emplace_back();
    }
    s_meshes[id] = {linear, (int)expanded.size()};
    return id;
}

void fried_mesh_destroy(int meshId)
{
    if (meshId < 0 || meshId >= (int)s_meshes.size() || !s_meshes[meshId].m_vertices)
    {
        return;
    }
    // The GPU may still be reading it for a frame that is not finished.
    fried_mesh_citro_leave();
    linearFree(s_meshes[meshId].m_vertices);
    s_meshes[meshId] = {nullptr, 0};
    s_freeMeshes.push_back(meshId);
}

bool fried_renderer_draws_meshes(int rendererId)
{
    return fried_renderer_get_width(rendererId) > 0;
}
