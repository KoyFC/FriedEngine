#include "math/real.h"
#include "graphics/mesh.h"
#include "graphics/mesh_sdl.h"

#include "graphics/display.h"
#include "graphics/mesh_geometry.h"

#include <SDL.h>

#include <psp2/gxm.h>
#include <psp2/kernel/modulemgr.h>
#include <psp2/kernel/sysmem.h>
#include <psp2/shacccg.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>

// Meshes drawn with GXM inside the scenes SDL's "VITA gxm" renderer runs. SDL
// ends its scene whenever its queue is flushed, so a run of meshes is a scene
// of its own, begun and ended through the calls sdl2-vita.patch exports, and
// SDL's state needs nothing put back but its clip, which the patch marks dirty.
// A scene starts with the depth at its far value and the stencil at 0, which
// is a depth clear for free, and is why the stencil test is set to always
// pass: SDL's clip would otherwise reject every pixel. The shaders are
// compiled on the console by libshacccg.suprx, which Sony's firmware does not
// carry, and the vertices are turned and lit as MeshPass does on the CPU.

extern "C"
{
    int FRIED_VITA_GXM_GetContext(SDL_Renderer *renderer, SceGxmContext **context, SceGxmShaderPatcher **shaderPatcher);
    void FRIED_VITA_GXM_BeginScene(SDL_Renderer *renderer);
    void FRIED_VITA_GXM_EndScene(SDL_Renderer *renderer);
}

namespace
{
    using Vertex = fried_mesh::Vertex;

    // GL culls back faces with a clockwise front. GXM, whose viewport has a negative y scale, culls the other winding, as the hardware showed.
    constexpr SceGxmCullMode s_cullMode = SCE_GXM_CULL_CCW;
    constexpr uint32_t s_indexCount = 65535;
    constexpr uint32_t s_pageSize = 4096;

    struct GpuBlock
    {
        SceUID m_uid = -1;
        void *m_base = nullptr;
    };

    struct Mesh
    {
        std::vector<Vertex> m_vertices;
        GpuBlock m_gpu;
        bool m_isUsed;
    };

    struct Uniforms
    {
        const SceGxmProgramParameter *m_clip;
        const SceGxmProgramParameter *m_normal;
        const SceGxmProgramParameter *m_light;
        const SceGxmProgramParameter *m_ambient;
    };

    std::vector<Mesh> s_meshes;
    std::vector<int> s_freeMeshes;

    int s_rendererId = -1;
    SDL_Renderer *s_renderer = nullptr;
    SceGxmContext *s_context = nullptr;
    SceGxmShaderPatcher *s_patcher = nullptr;
    void *s_vertexGxp = nullptr;
    void *s_fragmentGxp = nullptr;
    SceGxmShaderPatcherId s_vertexId = nullptr;
    SceGxmShaderPatcherId s_fragmentId = nullptr;
    SceGxmVertexProgram *s_vertexProgram = nullptr;
    SceGxmFragmentProgram *s_fragmentProgram = nullptr;
    Uniforms s_uniforms;
    GpuBlock s_indices;
    bool s_isViewSet = false;
    bool s_isInMeshMode = false;
    double s_lastView[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 3];
    FriedDisplayLayout s_layout;

    const char *s_vertexSource =
        "void main(\n"
        "    float3 a_position,\n"
        "    float4 a_color,\n"
        "    float3 a_normal,\n"
        "    uniform float4 u_clip[4],\n"
        "    uniform float4 u_normal[3],\n"
        "    uniform float4 u_light,\n"
        "    uniform float u_ambient,\n"
        "    out float4 v_position : POSITION,\n"
        "    out float4 v_color : COLOR)\n"
        "{\n"
        "    float4 point = float4(a_position, 1.0);\n"
        "    v_position = float4(dot(u_clip[0], point), dot(u_clip[1], point), dot(u_clip[2], point), dot(u_clip[3], point));\n"
        "    float3 normal = float3(dot(u_normal[0].xyz, a_normal), dot(u_normal[1].xyz, a_normal), dot(u_normal[2].xyz, a_normal));\n"
        "    normal = normalize(normal);\n"
        "    float facing = -dot(normal, u_light.xyz);\n"
        "    float brightness = u_ambient + (1.0 - u_ambient) * max(facing, 0.0);\n"
        "    float3 shade = floor(a_color.rgb * 255.0 * brightness + 0.001) / 255.0;\n"
        "    v_color = float4(shade, a_color.a);\n"
        "}\n";

    const char *s_fragmentSource =
        "float4 main(float4 v_color : COLOR)\n"
        "{\n"
        "    return v_color;\n"
        "}\n";

    SceShaccCgSourceFile s_sourceFile;

    SceShaccCgSourceFile *openSource(const char *, const SceShaccCgSourceLocation *, const SceShaccCgCompileOptions *, const char **)
    {
        return &s_sourceFile;
    }

    uint32_t roundUp(uint32_t size)
    {
        return (size + s_pageSize - 1) / s_pageSize * s_pageSize;
    }

    bool allocate(GpuBlock &block, uint32_t size)
    {
        block.m_uid = sceKernelAllocMemBlock("fried_mesh", SCE_KERNEL_MEMBLOCK_TYPE_USER_RW_UNCACHE, roundUp(size), nullptr);
        if (block.m_uid < 0)
        {
            block.m_uid = -1;
            return false;
        }
        sceKernelGetMemBlockBase(block.m_uid, &block.m_base);
        if (sceGxmMapMemory(block.m_base, roundUp(size), SCE_GXM_MEMORY_ATTRIB_READ) != 0)
        {
            sceKernelFreeMemBlock(block.m_uid);
            block = GpuBlock();
            return false;
        }
        return true;
    }

    void release(GpuBlock &block)
    {
        if (block.m_uid >= 0)
        {
            sceGxmUnmapMemory(block.m_base);
            sceKernelFreeMemBlock(block.m_uid);
        }
        block = GpuBlock();
    }

    bool loadCompiler()
    {
        static const char *const s_paths[] = {"ur0:data/libshacccg.suprx", "ur0:data/external/libshacccg.suprx"};
        for (const char *path : s_paths)
        {
            SceUID module = sceKernelLoadStartModule(path, 0, nullptr, 0, nullptr, nullptr);
            SDL_Log("Loading %s gave %08x", path, (unsigned)module);
            if (module >= 0)
            {
                return true;
            }
        }
        return false;
    }

    // A copy that outlives the compiler's output, or null.
    void *compile(const char *source, SceShaccCgTargetProfile profile)
    {
        SceShaccCgCompileOptions options;
        std::memset(&options, 0, sizeof(options));
        sceShaccCgInitializeCompileOptions(&options);
        options.mainSourceFile = "fried_mesh.cg";
        options.targetProfile = profile;
        options.entryFunctionName = "main";
        options.locale = SCE_SHACCCG_ENGLISH;

        SceShaccCgCallbackList callbacks;
        std::memset(&callbacks, 0, sizeof(callbacks));
        sceShaccCgInitializeCallbackList(&callbacks, SCE_SHACCCG_TRIVIAL);
        callbacks.openFile = openSource;

        s_sourceFile.fileName = options.mainSourceFile;
        s_sourceFile.text = source;
        s_sourceFile.size = (SceUInt32)std::strlen(source);

        const SceShaccCgCompileOutput *output = sceShaccCgCompileProgram(&options, &callbacks, 0);
        if (!output)
        {
            return nullptr;
        }
        void *copy = nullptr;
        if (output->programData && output->programSize > 0)
        {
            copy = std::malloc(output->programSize);
            if (copy)
            {
                std::memcpy(copy, output->programData, output->programSize);
            }
        }
        else
        {
            for (int index = 0; index < output->diagnosticCount; ++index)
            {
                SDL_Log("Shader compiler: %s", output->diagnostics[index].message);
            }
        }
        sceShaccCgDestroyCompileOutput(output);
        if (copy && sceGxmProgramCheck(static_cast<const SceGxmProgram *>(copy)) != 0)
        {
            std::free(copy);
            copy = nullptr;
        }
        return copy;
    }

    void releasePrograms()
    {
        if (s_patcher)
        {
            if (s_vertexProgram)
            {
                sceGxmShaderPatcherReleaseVertexProgram(s_patcher, s_vertexProgram);
            }
            if (s_fragmentProgram)
            {
                sceGxmShaderPatcherReleaseFragmentProgram(s_patcher, s_fragmentProgram);
            }
            if (s_vertexId)
            {
                sceGxmShaderPatcherUnregisterProgram(s_patcher, s_vertexId);
            }
            if (s_fragmentId)
            {
                sceGxmShaderPatcherUnregisterProgram(s_patcher, s_fragmentId);
            }
        }
        std::free(s_vertexGxp);
        std::free(s_fragmentGxp);
        s_vertexProgram = nullptr;
        s_fragmentProgram = nullptr;
        s_vertexId = nullptr;
        s_fragmentId = nullptr;
        s_vertexGxp = nullptr;
        s_fragmentGxp = nullptr;
    }

    bool buildPrograms()
    {
        if (!loadCompiler())
        {
            SDL_Log("libshacccg.suprx did not load, so meshes are drawn without the GPU");
            return false;
        }
        sceShaccCgSetDefaultAllocator(
            [](unsigned int size) -> void * { return std::malloc(size); },
            [](void *memory) { std::free(memory); });

        s_vertexGxp = compile(s_vertexSource, SCE_SHACCCG_PROFILE_VP);
        s_fragmentGxp = s_vertexGxp ? compile(s_fragmentSource, SCE_SHACCCG_PROFILE_FP) : nullptr;
        if (!s_vertexGxp || !s_fragmentGxp)
        {
            SDL_Log("The mesh shaders did not compile, so meshes are drawn without the GPU");
            releasePrograms();
            return false;
        }

        const SceGxmProgram *vertexProgram = static_cast<const SceGxmProgram *>(s_vertexGxp);
        const SceGxmProgram *fragmentProgram = static_cast<const SceGxmProgram *>(s_fragmentGxp);
        if (sceGxmShaderPatcherRegisterProgram(s_patcher, vertexProgram, &s_vertexId) != 0
            || sceGxmShaderPatcherRegisterProgram(s_patcher, fragmentProgram, &s_fragmentId) != 0)
        {
            releasePrograms();
            return false;
        }

        const SceGxmProgramParameter *position = sceGxmProgramFindParameterByName(vertexProgram, "a_position");
        const SceGxmProgramParameter *color = sceGxmProgramFindParameterByName(vertexProgram, "a_color");
        const SceGxmProgramParameter *normal = sceGxmProgramFindParameterByName(vertexProgram, "a_normal");
        s_uniforms.m_clip = sceGxmProgramFindParameterByName(vertexProgram, "u_clip");
        s_uniforms.m_normal = sceGxmProgramFindParameterByName(vertexProgram, "u_normal");
        s_uniforms.m_light = sceGxmProgramFindParameterByName(vertexProgram, "u_light");
        s_uniforms.m_ambient = sceGxmProgramFindParameterByName(vertexProgram, "u_ambient");
        if (!position || !color || !normal)
        {
            releasePrograms();
            return false;
        }

        SceGxmVertexAttribute attributes[3];
        attributes[0].streamIndex = 0;
        attributes[0].offset = offsetof(Vertex, m_position);
        attributes[0].format = SCE_GXM_ATTRIBUTE_FORMAT_F32;
        attributes[0].componentCount = 3;
        attributes[0].regIndex = (uint16_t)sceGxmProgramParameterGetResourceIndex(position);
        attributes[1].streamIndex = 0;
        attributes[1].offset = offsetof(Vertex, m_color);
        attributes[1].format = SCE_GXM_ATTRIBUTE_FORMAT_U8N;
        attributes[1].componentCount = 4;
        attributes[1].regIndex = (uint16_t)sceGxmProgramParameterGetResourceIndex(color);
        attributes[2].streamIndex = 0;
        attributes[2].offset = offsetof(Vertex, m_normal);
        attributes[2].format = SCE_GXM_ATTRIBUTE_FORMAT_F32;
        attributes[2].componentCount = 3;
        attributes[2].regIndex = (uint16_t)sceGxmProgramParameterGetResourceIndex(normal);

        SceGxmVertexStream stream;
        stream.stride = sizeof(Vertex);
        stream.indexSource = SCE_GXM_INDEX_SOURCE_INDEX_16BIT;

        SceGxmBlendInfo blend;
        std::memset(&blend, 0, sizeof(blend));
        blend.colorMask = SCE_GXM_COLOR_MASK_ALL;
        blend.colorFunc = SCE_GXM_BLEND_FUNC_ADD;
        blend.alphaFunc = SCE_GXM_BLEND_FUNC_ADD;
        blend.colorSrc = SCE_GXM_BLEND_FACTOR_SRC_ALPHA;
        blend.colorDst = SCE_GXM_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        blend.alphaSrc = SCE_GXM_BLEND_FACTOR_ONE;
        blend.alphaDst = SCE_GXM_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;

        if (sceGxmShaderPatcherCreateVertexProgram(s_patcher, s_vertexId, attributes, 3, &stream, 1, &s_vertexProgram) != 0
            || sceGxmShaderPatcherCreateFragmentProgram(s_patcher, s_fragmentId, SCE_GXM_OUTPUT_REGISTER_FORMAT_UCHAR4, SCE_GXM_MULTISAMPLE_NONE, &blend, vertexProgram, &s_fragmentProgram) != 0)
        {
            releasePrograms();
            return false;
        }
        return true;
    }

    bool buildIndices()
    {
        if (!allocate(s_indices, s_indexCount * sizeof(uint16_t)))
        {
            return false;
        }
        uint16_t *indices = static_cast<uint16_t *>(s_indices.m_base);
        for (uint32_t index = 0; index < s_indexCount; ++index)
        {
            indices[index] = (uint16_t)index;
        }
        return true;
    }

    bool uploadIfNeeded(Mesh &mesh)
    {
        if (mesh.m_gpu.m_uid >= 0)
        {
            return true;
        }
        if (!allocate(mesh.m_gpu, (uint32_t)(mesh.m_vertices.size() * sizeof(Vertex))))
        {
            return false;
        }
        std::memcpy(mesh.m_gpu.m_base, mesh.m_vertices.data(), mesh.m_vertices.size() * sizeof(Vertex));
        return true;
    }

    // A fresh scene starts with a clear depth, so this is also how the depth starts again.
    void beginScene()
    {
        FRIED_VITA_GXM_BeginScene(s_renderer);
        sceGxmSetVertexProgram(s_context, s_vertexProgram);
        sceGxmSetFragmentProgram(s_context, s_fragmentProgram);
        float halfWidth = s_layout.m_viewportWidth * 0.5f;
        float halfHeight = s_layout.m_viewportHeight * 0.5f;
        sceGxmSetViewport(s_context, s_layout.m_viewportX + halfWidth, halfWidth, s_layout.m_viewportY + halfHeight, -halfHeight, 0.5f, 0.5f);
        sceGxmSetFrontDepthFunc(s_context, SCE_GXM_DEPTH_FUNC_LESS);
        sceGxmSetFrontDepthWriteEnable(s_context, SCE_GXM_DEPTH_WRITE_ENABLED);
        sceGxmSetCullMode(s_context, s_cullMode);
        sceGxmSetFrontStencilFunc(s_context, SCE_GXM_STENCIL_FUNC_ALWAYS, SCE_GXM_STENCIL_OP_KEEP, SCE_GXM_STENCIL_OP_KEEP, SCE_GXM_STENCIL_OP_KEEP, 0xFF, 0xFF);
    }

    void setUniforms(const fried_mesh::Transform &transform)
    {
        void *buffer = nullptr;
        if (sceGxmReserveVertexDefaultUniformBuffer(s_context, &buffer) != 0 || !buffer)
        {
            return;
        }
        float clip[16];
        for (int row = 0; row < 4; ++row)
        {
            for (int column = 0; column < 4; ++column)
            {
                clip[row * 4 + column] = (float)transform.m_clip[row][column];
            }
        }
        float normal[12];
        for (int row = 0; row < 3; ++row)
        {
            for (int column = 0; column < 3; ++column)
            {
                normal[row * 4 + column] = transform.m_normal[row][column];
            }
            normal[row * 4 + 3] = 0.0f;
        }
        float light[4] = {transform.m_light[0], transform.m_light[1], transform.m_light[2], 0.0f};
        float ambient = transform.m_ambient;

        if (s_uniforms.m_clip)
        {
            sceGxmSetUniformDataF(buffer, s_uniforms.m_clip, 0, 16, clip);
        }
        if (s_uniforms.m_normal)
        {
            sceGxmSetUniformDataF(buffer, s_uniforms.m_normal, 0, 12, normal);
        }
        if (s_uniforms.m_light)
        {
            sceGxmSetUniformDataF(buffer, s_uniforms.m_light, 0, 4, light);
        }
        if (s_uniforms.m_ambient)
        {
            sceGxmSetUniformDataF(buffer, s_uniforms.m_ambient, 0, 1, &ambient);
        }
    }

    void releaseGpuMemory()
    {
        sceGxmFinish(s_context);
        for (Mesh &mesh : s_meshes)
        {
            release(mesh.m_gpu);
        }
        release(s_indices);
    }
}

bool fried_mesh_sdl_attach(int rendererId, void *sdlRenderer)
{
    SDL_Renderer *renderer = static_cast<SDL_Renderer *>(sdlRenderer);
    if (s_rendererId >= 0 || !renderer)
    {
        return false;
    }

    SDL_RendererInfo info;
    if (SDL_GetRendererInfo(renderer, &info) != 0 || SDL_strcmp(info.name, "VITA gxm") != 0)
    {
        return false;
    }
    if (FRIED_VITA_GXM_GetContext(renderer, &s_context, &s_patcher) != 0)
    {
        return false;
    }
    if (!buildPrograms())
    {
        return false;
    }
    if (!buildIndices())
    {
        releasePrograms();
        return false;
    }

    SDL_Log("Meshes are drawn with GXM, with shaders compiled on the console");
    s_renderer = renderer;
    s_rendererId = rendererId;
    s_isViewSet = false;
    s_isInMeshMode = false;
    std::memset(s_lastView, 0, sizeof(s_lastView));
    return true;
}

void fried_mesh_sdl_detach(int rendererId)
{
    if (rendererId != s_rendererId)
    {
        return;
    }
    fried_mesh_sdl_leave();
    releaseGpuMemory();
    releasePrograms();
    s_rendererId = -1;
    s_renderer = nullptr;
    s_context = nullptr;
    s_patcher = nullptr;
}

void fried_mesh_sdl_end_frame(int rendererId)
{
    if (rendererId == s_rendererId)
    {
        s_isViewSet = false;
    }
}

void fried_mesh_sdl_leave()
{
    if (!s_isInMeshMode)
    {
        return;
    }
    s_isInMeshMode = false;
    sceGxmSetFrontDepthFunc(s_context, SCE_GXM_DEPTH_FUNC_ALWAYS);
    sceGxmSetFrontDepthWriteEnable(s_context, SCE_GXM_DEPTH_WRITE_ENABLED);
    sceGxmSetCullMode(s_context, SCE_GXM_CULL_NONE);
    FRIED_VITA_GXM_EndScene(s_renderer);
}

int fried_mesh_create(const fried_real *vertices, int vertexCount, const int *indices, const int *argbColors, int triangleCount)
{
    if (s_rendererId < 0 || !vertices || !indices || !argbColors || triangleCount <= 0)
    {
        return -1;
    }

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

    Mesh &mesh = s_meshes[id];
    mesh.m_gpu = GpuBlock();
    mesh.m_isUsed = fried_mesh::expand(vertices, vertexCount, indices, argbColors, triangleCount, mesh.m_vertices);
    if (!mesh.m_isUsed)
    {
        mesh.m_vertices.clear();
        s_freeMeshes.push_back(id);
        return -1;
    }
    return id;
}

void fried_mesh_destroy(int meshId)
{
    if (meshId < 0 || meshId >= (int)s_meshes.size() || !s_meshes[meshId].m_isUsed)
    {
        return;
    }

    Mesh &mesh = s_meshes[meshId];
    if (mesh.m_gpu.m_uid >= 0 && s_rendererId >= 0)
    {
        fried_mesh_sdl_leave();
        sceGxmFinish(s_context);
        release(mesh.m_gpu);
    }
    mesh.m_gpu = GpuBlock();
    mesh.m_isUsed = false;
    std::vector<Vertex>().swap(mesh.m_vertices);
    s_freeMeshes.push_back(meshId);
}

bool fried_renderer_draws_meshes(int rendererId)
{
    return s_rendererId >= 0 && rendererId == s_rendererId;
}

void fried_renderer_draw_mesh(int rendererId, int meshId, const fried_real *placement, bool hasCamera, double zoom, double cameraX, double cameraY)
{
    if (rendererId != s_rendererId || !placement || meshId < 0 || meshId >= (int)s_meshes.size() || !s_meshes[meshId].m_isUsed)
    {
        return;
    }
    Mesh &mesh = s_meshes[meshId];

    int outputWidth = 0, outputHeight = 0;
    SDL_GetRendererOutputSize(s_renderer, &outputWidth, &outputHeight);
    FriedDisplayLayout layout = fried_display_layout(outputWidth, outputHeight);
    if (layout.m_viewportWidth <= 0 || layout.m_viewportHeight <= 0)
    {
        return;
    }

    fried_mesh::Transform transform;
    if (!fried_mesh::place(placement, hasCamera, zoom, cameraX, cameraY, layout, layout.m_viewportX, layout.m_viewportY, layout.m_viewportWidth, layout.m_viewportHeight, transform))
    {
        return;
    }

    if (!s_isInMeshMode)
    {
        SDL_RenderFlush(s_renderer);
        if (!uploadIfNeeded(mesh))
        {
            return;
        }
        s_layout = layout;
        beginScene();
        s_isInMeshMode = true;
        s_isViewSet = false;
    }
    else if (!uploadIfNeeded(mesh))
    {
        return;
    }

    // Meshes of one view share a depth buffer, which starts again each frame
    // and whenever the view changes, as another scene's meshes begin.
    double view[sizeof(s_lastView) / sizeof(double)];
    std::memcpy(view, placement + FRIED_MESH_CAMERA_X, (FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X) * sizeof(double));
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X] = hasCamera ? zoom : 0.0;
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 1] = hasCamera ? cameraX : 0.0;
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 2] = hasCamera ? cameraY : 0.0;
    if (!s_isViewSet || std::memcmp(view, s_lastView, sizeof(view)) != 0)
    {
        if (s_isViewSet)
        {
            FRIED_VITA_GXM_EndScene(s_renderer);
            beginScene();
        }
        std::memcpy(s_lastView, view, sizeof(view));
        s_isViewSet = true;
    }

    uint32_t total = (uint32_t)mesh.m_vertices.size();
    for (uint32_t first = 0; first < total; first += s_indexCount)
    {
        uint32_t count = std::min(s_indexCount, total - first);
        setUniforms(transform);
        sceGxmSetVertexStream(s_context, 0, static_cast<uint8_t *>(mesh.m_gpu.m_base) + (size_t)first * sizeof(Vertex));
        sceGxmDraw(s_context, SCE_GXM_PRIMITIVE_TRIANGLES, SCE_GXM_INDEX_FORMAT_U16, s_indices.m_base, count);
    }
}
