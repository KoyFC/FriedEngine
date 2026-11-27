#include "math/real.h"
#include "graphics/mesh.h"
#include "graphics/mesh_sdl.h"

#include "graphics/display.h"
#include "graphics/mesh_geometry.h"
#include "graphics/texture.h"

#include <SDL.h>
#include <SDL_opengl.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <vector>

// Meshes drawn with the GL context SDL's renderer made, in the middle of its
// own drawing. SDL's queue is flushed first and the few pieces of state both
// sides use are put back as they were found, so SDL goes on knowing what it
// last set. The mesh's corners are turned and lit by the vertex shader, one
// shade for each face, in the arithmetic MeshPass has on the CPU.

namespace
{
    // Not 3, which a compatibility context reads as SDL's color array.
    constexpr GLuint s_positionAttribute = 0;
    constexpr GLuint s_colorAttribute = 1;
    constexpr GLuint s_normalAttribute = 2;
    constexpr GLuint s_uvAttribute = 6;
    constexpr GLuint s_attributes[] = {s_positionAttribute, s_colorAttribute, s_normalAttribute, s_uvAttribute};
    constexpr int s_attributeCount = 4;
    constexpr int s_clientStateCount = 3;

    using Vertex = fried_mesh::TexturedVertex;

    struct Range
    {
        int m_first;
        int m_count;
        int m_textureId;
        bool m_repeats;
    };

    struct Mesh
    {
        std::vector<Vertex> m_vertices;
        std::vector<Range> m_ranges;
        GLuint m_buffer;
        bool m_isUsed;
    };

    struct Functions
    {
        const GLubyte *(APIENTRY *m_getString)(GLenum);
        void (APIENTRY *m_enable)(GLenum);
        void (APIENTRY *m_disable)(GLenum);
        GLboolean (APIENTRY *m_isEnabled)(GLenum);
        void (APIENTRY *m_getIntegerv)(GLenum, GLint *);
        void (APIENTRY *m_viewport)(GLint, GLint, GLsizei, GLsizei);
        void (APIENTRY *m_clear)(GLbitfield);
        void (APIENTRY *m_depthFunc)(GLenum);
        void (APIENTRY *m_depthMask)(GLboolean);
        void (APIENTRY *m_cullFace)(GLenum);
        void (APIENTRY *m_frontFace)(GLenum);
        void (APIENTRY *m_drawArrays)(GLenum, GLint, GLsizei);
        GLenum (APIENTRY *m_getError)();
        GLuint (APIENTRY *m_createShader)(GLenum);
        void (APIENTRY *m_shaderSource)(GLuint, GLsizei, const GLchar *const *, const GLint *);
        void (APIENTRY *m_compileShader)(GLuint);
        void (APIENTRY *m_getShaderiv)(GLuint, GLenum, GLint *);
        void (APIENTRY *m_deleteShader)(GLuint);
        GLuint (APIENTRY *m_createProgram)();
        void (APIENTRY *m_attachShader)(GLuint, GLuint);
        void (APIENTRY *m_bindAttribLocation)(GLuint, GLuint, const GLchar *);
        void (APIENTRY *m_linkProgram)(GLuint);
        void (APIENTRY *m_getProgramiv)(GLuint, GLenum, GLint *);
        void (APIENTRY *m_deleteProgram)(GLuint);
        void (APIENTRY *m_useProgram)(GLuint);
        GLint (APIENTRY *m_getUniformLocation)(GLuint, const GLchar *);
        void (APIENTRY *m_uniformMatrix4fv)(GLint, GLsizei, GLboolean, const GLfloat *);
        void (APIENTRY *m_uniformMatrix3fv)(GLint, GLsizei, GLboolean, const GLfloat *);
        void (APIENTRY *m_uniform3f)(GLint, GLfloat, GLfloat, GLfloat);
        void (APIENTRY *m_uniform1f)(GLint, GLfloat);
        void (APIENTRY *m_genBuffers)(GLsizei, GLuint *);
        void (APIENTRY *m_deleteBuffers)(GLsizei, const GLuint *);
        void (APIENTRY *m_bindBuffer)(GLenum, GLuint);
        void (APIENTRY *m_bufferData)(GLenum, GLsizeiptr, const void *, GLenum);
        void (APIENTRY *m_enableVertexAttribArray)(GLuint);
        void (APIENTRY *m_disableVertexAttribArray)(GLuint);
        void (APIENTRY *m_vertexAttribPointer)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void *);
        void (APIENTRY *m_getVertexAttribiv)(GLuint, GLenum, GLint *);
        void (APIENTRY *m_activeTexture)(GLenum);
        void (APIENTRY *m_bindTexture)(GLenum, GLuint);
        void (APIENTRY *m_genTextures)(GLsizei, GLuint *);
        void (APIENTRY *m_deleteTextures)(GLsizei, const GLuint *);
        void (APIENTRY *m_texImage2D)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
        void (APIENTRY *m_texParameteri)(GLenum, GLenum, GLint);
        void (APIENTRY *m_getTexParameteriv)(GLenum, GLenum, GLint *);
        void (APIENTRY *m_uniform1i)(GLint, GLint);
        void (APIENTRY *m_uniform2f)(GLint, GLfloat, GLfloat);
        void (APIENTRY *m_enableClientState)(GLenum);
        void (APIENTRY *m_disableClientState)(GLenum);
    };

    struct Uniforms
    {
        GLint m_modelViewProjection;
        GLint m_normalMatrix;
        GLint m_light;
        GLint m_ambient;
        GLint m_texture;
        GLint m_uvScale;
    };

    // What SDL had set that a mesh draws over.
    struct SavedState
    {
        GLint m_program;
        GLint m_arrayBuffer;
        GLint m_viewport[4];
        // SDL is not told when a mesh binds a texture, so its binding is put back.
        GLint m_activeTexture;
        GLint m_texture;
        bool m_isTextureEnabled;
        bool m_isScissorEnabled;
        bool m_isAttributeEnabled[s_attributeCount];
        bool m_isClientStateEnabled[s_clientStateCount];
    };

    std::vector<Mesh> s_meshes;
    std::vector<int> s_freeMeshes;

    Functions s_gl;
    Uniforms s_uniforms;
    GLuint s_program = 0;
    int s_rendererId = -1;
    SDL_Renderer *s_renderer = nullptr;
    SDL_Window *s_window = nullptr;
    SDL_GLContext s_context = nullptr;
    bool s_isEs = false;
    bool s_isDepthCleared = false;
    bool s_isStateSet = false;
    bool s_isInMeshMode = false;
    SavedState s_saved;
    // What a surface with no image is painted with.
    GLuint s_whiteTexture = 0;
    fried_real s_lastView[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 3];

    const char *s_vertexSource =
        "attribute vec3 a_position;\n"
        "attribute vec4 a_color;\n"
        "attribute vec3 a_normal;\n"
        "attribute vec2 a_uv;\n"
        "uniform vec2 u_uvScale;\n"
        "uniform mat4 u_modelViewProjection;\n"
        "uniform mat3 u_normalMatrix;\n"
        "uniform vec3 u_light;\n"
        "uniform float u_ambient;\n"
        "varying vec4 v_color;\n"
        "varying vec2 v_uv;\n"
        "void main()\n"
        "{\n"
        "    v_uv = a_uv * u_uvScale;\n"
        "    gl_Position = u_modelViewProjection * vec4(a_position, 1.0);\n"
        "    vec3 normal = normalize(u_normalMatrix * a_normal);\n"
        "    float facing = -dot(normal, u_light);\n"
        "    float brightness = u_ambient + (1.0 - u_ambient) * max(facing, 0.0);\n"
        "    vec3 shade = floor(a_color.rgb * 255.0 * brightness + 0.001) / 255.0;\n"
        "    v_color = vec4(shade, a_color.a);\n"
        "}\n";

    const char *s_fragmentSource =
        "varying vec4 v_color;\n"
        "varying vec2 v_uv;\n"
        "uniform sampler2D u_texture;\n"
        "void main()\n"
        "{\n"
        "    vec4 texel = texture2D(u_texture, v_uv);\n"
        "    if (texel.a < 0.5)\n"
        "    {\n"
        "        discard;\n"
        "    }\n"
        "    gl_FragColor = v_color * texel;\n"
        "}\n";

    template <typename Function>
    bool load(Function &function, const char *name)
    {
        function = reinterpret_cast<Function>(SDL_GL_GetProcAddress(name));
        return function != nullptr;
    }

    bool loadFunctions()
    {
        bool ok = true;
        ok &= load(s_gl.m_getString, "glGetString");
        ok &= load(s_gl.m_enable, "glEnable");
        ok &= load(s_gl.m_disable, "glDisable");
        ok &= load(s_gl.m_isEnabled, "glIsEnabled");
        ok &= load(s_gl.m_getIntegerv, "glGetIntegerv");
        ok &= load(s_gl.m_viewport, "glViewport");
        ok &= load(s_gl.m_clear, "glClear");
        ok &= load(s_gl.m_depthFunc, "glDepthFunc");
        ok &= load(s_gl.m_depthMask, "glDepthMask");
        ok &= load(s_gl.m_cullFace, "glCullFace");
        ok &= load(s_gl.m_frontFace, "glFrontFace");
        ok &= load(s_gl.m_drawArrays, "glDrawArrays");
        ok &= load(s_gl.m_getError, "glGetError");
        ok &= load(s_gl.m_createShader, "glCreateShader");
        ok &= load(s_gl.m_shaderSource, "glShaderSource");
        ok &= load(s_gl.m_compileShader, "glCompileShader");
        ok &= load(s_gl.m_getShaderiv, "glGetShaderiv");
        ok &= load(s_gl.m_deleteShader, "glDeleteShader");
        ok &= load(s_gl.m_createProgram, "glCreateProgram");
        ok &= load(s_gl.m_attachShader, "glAttachShader");
        ok &= load(s_gl.m_bindAttribLocation, "glBindAttribLocation");
        ok &= load(s_gl.m_linkProgram, "glLinkProgram");
        ok &= load(s_gl.m_getProgramiv, "glGetProgramiv");
        ok &= load(s_gl.m_deleteProgram, "glDeleteProgram");
        ok &= load(s_gl.m_useProgram, "glUseProgram");
        ok &= load(s_gl.m_getUniformLocation, "glGetUniformLocation");
        ok &= load(s_gl.m_uniformMatrix4fv, "glUniformMatrix4fv");
        ok &= load(s_gl.m_uniformMatrix3fv, "glUniformMatrix3fv");
        ok &= load(s_gl.m_uniform3f, "glUniform3f");
        ok &= load(s_gl.m_uniform1f, "glUniform1f");
        ok &= load(s_gl.m_genBuffers, "glGenBuffers");
        ok &= load(s_gl.m_deleteBuffers, "glDeleteBuffers");
        ok &= load(s_gl.m_bindBuffer, "glBindBuffer");
        ok &= load(s_gl.m_bufferData, "glBufferData");
        ok &= load(s_gl.m_enableVertexAttribArray, "glEnableVertexAttribArray");
        ok &= load(s_gl.m_disableVertexAttribArray, "glDisableVertexAttribArray");
        ok &= load(s_gl.m_vertexAttribPointer, "glVertexAttribPointer");
        ok &= load(s_gl.m_getVertexAttribiv, "glGetVertexAttribiv");
        ok &= load(s_gl.m_activeTexture, "glActiveTexture");
        ok &= load(s_gl.m_bindTexture, "glBindTexture");
        ok &= load(s_gl.m_genTextures, "glGenTextures");
        ok &= load(s_gl.m_deleteTextures, "glDeleteTextures");
        ok &= load(s_gl.m_texImage2D, "glTexImage2D");
        ok &= load(s_gl.m_texParameteri, "glTexParameteri");
        ok &= load(s_gl.m_getTexParameteriv, "glGetTexParameteriv");
        ok &= load(s_gl.m_uniform1i, "glUniform1i");
        ok &= load(s_gl.m_uniform2f, "glUniform2f");
        if (!s_isEs)
        {
            ok &= load(s_gl.m_enableClientState, "glEnableClientState");
            ok &= load(s_gl.m_disableClientState, "glDisableClientState");
        }
        return ok;
    }

    GLuint compile(GLenum type, const char *body)
    {
        const char *prefix = s_isEs
            ? (type == GL_VERTEX_SHADER ? "#version 100\nprecision highp float;\n" : "#version 100\nprecision mediump float;\n")
            : "#version 110\n";
        const char *sources[2] = {prefix, body};
        GLuint shader = s_gl.m_createShader(type);
        s_gl.m_shaderSource(shader, 2, sources, nullptr);
        s_gl.m_compileShader(shader);
        GLint isCompiled = 0;
        s_gl.m_getShaderiv(shader, GL_COMPILE_STATUS, &isCompiled);
        if (!isCompiled)
        {
            s_gl.m_deleteShader(shader);
            return 0;
        }
        return shader;
    }

    bool buildProgram()
    {
        GLuint vertex = compile(GL_VERTEX_SHADER, s_vertexSource);
        GLuint fragment = compile(GL_FRAGMENT_SHADER, s_fragmentSource);
        if (!vertex || !fragment)
        {
            if (vertex)
            {
                s_gl.m_deleteShader(vertex);
            }
            if (fragment)
            {
                s_gl.m_deleteShader(fragment);
            }
            return false;
        }

        s_program = s_gl.m_createProgram();
        s_gl.m_attachShader(s_program, vertex);
        s_gl.m_attachShader(s_program, fragment);
        s_gl.m_bindAttribLocation(s_program, s_positionAttribute, "a_position");
        s_gl.m_bindAttribLocation(s_program, s_colorAttribute, "a_color");
        s_gl.m_bindAttribLocation(s_program, s_normalAttribute, "a_normal");
        s_gl.m_bindAttribLocation(s_program, s_uvAttribute, "a_uv");
        s_gl.m_linkProgram(s_program);
        s_gl.m_deleteShader(vertex);
        s_gl.m_deleteShader(fragment);

        GLint isLinked = 0;
        s_gl.m_getProgramiv(s_program, GL_LINK_STATUS, &isLinked);
        if (!isLinked)
        {
            s_gl.m_deleteProgram(s_program);
            s_program = 0;
            return false;
        }

        s_uniforms.m_modelViewProjection = s_gl.m_getUniformLocation(s_program, "u_modelViewProjection");
        s_uniforms.m_normalMatrix = s_gl.m_getUniformLocation(s_program, "u_normalMatrix");
        s_uniforms.m_light = s_gl.m_getUniformLocation(s_program, "u_light");
        s_uniforms.m_ambient = s_gl.m_getUniformLocation(s_program, "u_ambient");
        s_uniforms.m_texture = s_gl.m_getUniformLocation(s_program, "u_texture");
        s_uniforms.m_uvScale = s_gl.m_getUniformLocation(s_program, "u_uvScale");
        return true;
    }

    bool isContextCurrent()
    {
        return s_context && SDL_GL_GetCurrentContext() == s_context;
    }

    // SDL's own calls make its context current when they need it, so after
    // flushing the queue it is the current one unless another window's
    // renderer has drawn since.
    bool prepareContext()
    {
        fried_mesh_sdl_leave();
        SDL_RenderFlush(s_renderer);
        if (!isContextCurrent())
        {
            return SDL_GL_MakeCurrent(s_window, s_context) == 0;
        }
        return true;
    }

    void uploadIfNeeded(Mesh &mesh)
    {
        if (mesh.m_buffer)
        {
            return;
        }
        s_gl.m_genBuffers(1, &mesh.m_buffer);
        s_gl.m_bindBuffer(GL_ARRAY_BUFFER, mesh.m_buffer);
        s_gl.m_bufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(mesh.m_vertices.size() * sizeof(Vertex)), mesh.m_vertices.data(), GL_STATIC_DRAW);
    }

    void saveState(SavedState &state)
    {
        s_gl.m_getIntegerv(GL_CURRENT_PROGRAM, &state.m_program);
        s_gl.m_getIntegerv(GL_ARRAY_BUFFER_BINDING, &state.m_arrayBuffer);
        s_gl.m_getIntegerv(GL_VIEWPORT, state.m_viewport);
        state.m_isScissorEnabled = s_gl.m_isEnabled(GL_SCISSOR_TEST) != GL_FALSE;
        s_gl.m_getIntegerv(GL_ACTIVE_TEXTURE, &state.m_activeTexture);
        s_gl.m_getIntegerv(GL_TEXTURE_BINDING_2D, &state.m_texture);
        state.m_isTextureEnabled = !s_isEs && s_gl.m_isEnabled(GL_TEXTURE_2D) != GL_FALSE;
        for (int index = 0; index < s_attributeCount; ++index)
        {
            GLint isEnabled = 0;
            s_gl.m_getVertexAttribiv(s_attributes[index], GL_VERTEX_ATTRIB_ARRAY_ENABLED, &isEnabled);
            state.m_isAttributeEnabled[index] = isEnabled != 0;
        }
        if (!s_isEs)
        {
            state.m_isClientStateEnabled[0] = s_gl.m_isEnabled(GL_VERTEX_ARRAY) != GL_FALSE;
            state.m_isClientStateEnabled[1] = s_gl.m_isEnabled(GL_COLOR_ARRAY) != GL_FALSE;
            state.m_isClientStateEnabled[2] = s_gl.m_isEnabled(GL_TEXTURE_COORD_ARRAY) != GL_FALSE;
        }
    }

    void restoreState(const SavedState &state)
    {
        s_gl.m_disable(GL_DEPTH_TEST);
        s_gl.m_disable(GL_CULL_FACE);
        for (int index = 0; index < s_attributeCount; ++index)
        {
            if (state.m_isAttributeEnabled[index])
            {
                s_gl.m_enableVertexAttribArray(s_attributes[index]);
            }
            else
            {
                s_gl.m_disableVertexAttribArray(s_attributes[index]);
            }
        }
        if (!s_isEs)
        {
            static const GLenum clientStates[s_clientStateCount] = {GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY};
            for (int index = 0; index < s_clientStateCount; ++index)
            {
                if (state.m_isClientStateEnabled[index])
                {
                    s_gl.m_enableClientState(clientStates[index]);
                }
                else
                {
                    s_gl.m_disableClientState(clientStates[index]);
                }
            }
        }
        s_gl.m_bindBuffer(GL_ARRAY_BUFFER, (GLuint)state.m_arrayBuffer);
        s_gl.m_activeTexture((GLenum)state.m_activeTexture);
        s_gl.m_bindTexture(GL_TEXTURE_2D, (GLuint)state.m_texture);
        if (!s_isEs)
        {
            if (state.m_isTextureEnabled)
            {
                s_gl.m_enable(GL_TEXTURE_2D);
            }
            else
            {
                s_gl.m_disable(GL_TEXTURE_2D);
            }
        }
        s_gl.m_useProgram((GLuint)state.m_program);
        s_gl.m_viewport(state.m_viewport[0], state.m_viewport[1], state.m_viewport[2], state.m_viewport[3]);
        if (state.m_isScissorEnabled)
        {
            s_gl.m_enable(GL_SCISSOR_TEST);
        }
    }

    // The state a mesh is drawn with stays set from here until fried_mesh_sdl_leave().
    bool enterMeshMode(const FriedDisplayLayout &layout, int outputHeight)
    {
        if (!prepareContext())
        {
            return false;
        }
        saveState(s_saved);

        s_gl.m_viewport(layout.m_viewportX, outputHeight - layout.m_viewportY - layout.m_viewportHeight, layout.m_viewportWidth, layout.m_viewportHeight);
        s_gl.m_disable(GL_SCISSOR_TEST);
        if (!s_isStateSet)
        {
            s_gl.m_depthFunc(GL_LESS);
            s_gl.m_depthMask(GL_TRUE);
            s_gl.m_cullFace(GL_BACK);
            s_gl.m_frontFace(GL_CW);
            s_isStateSet = true;
        }
        s_gl.m_useProgram(s_program);
        for (int index = 0; index < s_attributeCount; ++index)
        {
            s_gl.m_enableVertexAttribArray(s_attributes[index]);
        }
        s_gl.m_activeTexture(GL_TEXTURE0);
        s_gl.m_uniform1i(s_uniforms.m_texture, 0);
        s_gl.m_enable(GL_DEPTH_TEST);
        s_gl.m_enable(GL_CULL_FACE);

        // The light is set again with the first mesh of the run.
        s_isDepthCleared = false;
        s_isInMeshMode = true;
        return true;
    }

    void drawRange(const Range &range)
    {
        float scaleU = 1.0f;
        float scaleV = 1.0f;
        bool isTextured = false;
        SDL_Texture *texture = range.m_textureId >= 0 ? fried_texture_get_sdl(range.m_textureId) : nullptr;
        GLint wrapS = 0, wrapT = 0;
        bool isWrapChanged = false;
        if (texture && SDL_GL_BindTexture(texture, &scaleU, &scaleV) == 0 && scaleU <= 1.0f && scaleV <= 1.0f)
        {
            isTextured = true;
            if (range.m_repeats && scaleU == 1.0f && scaleV == 1.0f)
            {
                s_gl.m_getTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, &wrapS);
                s_gl.m_getTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, &wrapT);
                s_gl.m_texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
                s_gl.m_texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
                isWrapChanged = true;
            }
        }
        if (!isTextured)
        {
            scaleU = 1.0f;
            scaleV = 1.0f;
            s_gl.m_bindTexture(GL_TEXTURE_2D, s_whiteTexture);
        }
        s_gl.m_uniform2f(s_uniforms.m_uvScale, scaleU, scaleV);
        s_gl.m_drawArrays(GL_TRIANGLES, range.m_first, range.m_count);
        if (isWrapChanged)
        {
            s_gl.m_texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapS);
            s_gl.m_texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapT);
        }
    }

    void releaseBuffers()
    {
        for (Mesh &mesh : s_meshes)
        {
            if (mesh.m_buffer)
            {
                s_gl.m_deleteBuffers(1, &mesh.m_buffer);
                mesh.m_buffer = 0;
            }
        }
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
    if (SDL_GetRendererInfo(renderer, &info) != 0)
    {
        return false;
    }
    bool isOpenGl = SDL_strcmp(info.name, "opengl") == 0;
    bool isOpenGlEs = SDL_strcmp(info.name, "opengles2") == 0;
    if (!isOpenGl && !isOpenGlEs)
    {
        return false;
    }

    SDL_Window *window = SDL_RenderGetWindow(renderer);
    SDL_GLContext context = SDL_GL_GetCurrentContext();
    int depthBits = 0;
    if (!window || !context || SDL_GL_GetAttribute(SDL_GL_DEPTH_SIZE, &depthBits) != 0 || depthBits <= 0)
    {
        return false;
    }

    s_isEs = isOpenGlEs;
    s_context = context;
    if (!loadFunctions() || !buildProgram())
    {
        s_context = nullptr;
        return false;
    }

    {
        GLint boundTexture = 0;
        s_gl.m_getIntegerv(GL_TEXTURE_BINDING_2D, &boundTexture);
        const unsigned char white[4] = {255, 255, 255, 255};
        s_gl.m_genTextures(1, &s_whiteTexture);
        s_gl.m_bindTexture(GL_TEXTURE_2D, s_whiteTexture);
        s_gl.m_texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        s_gl.m_texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        s_gl.m_texImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, white);
        s_gl.m_bindTexture(GL_TEXTURE_2D, (GLuint)boundTexture);
    }

    SDL_Log("Meshes are drawn by %s, %s, with %d depth bits", s_gl.m_getString(GL_RENDERER), s_gl.m_getString(GL_VERSION), depthBits);
    s_renderer = renderer;
    s_window = window;
    s_rendererId = rendererId;
    s_isDepthCleared = false;
    s_isStateSet = false;
    std::memset(s_lastView, 0, sizeof(s_lastView));
    return true;
}

void fried_mesh_sdl_detach(int rendererId)
{
    if (rendererId != s_rendererId)
    {
        return;
    }
    if (prepareContext())
    {
        releaseBuffers();
        s_gl.m_deleteProgram(s_program);
        if (s_whiteTexture)
        {
            s_gl.m_deleteTextures(1, &s_whiteTexture);
        }
    }
    s_whiteTexture = 0;
    s_program = 0;
    s_rendererId = -1;
    s_renderer = nullptr;
    s_window = nullptr;
    s_context = nullptr;
}

void fried_mesh_sdl_end_frame(int rendererId)
{
    if (rendererId == s_rendererId)
    {
        s_isDepthCleared = false;
    }
}

void fried_mesh_sdl_leave()
{
    if (s_isInMeshMode)
    {
        s_isInMeshMode = false;
        restoreState(s_saved);
    }
}

int fried_mesh_create(const fried_real *vertices, const fried_real *uvs, int vertexCount, const int *indices, const int *argbColors, int triangleCount,
                      const int *surfaceFirstTriangles, const int *surfaceTextureIds, int surfaceCount)
{
    if (s_rendererId < 0 || !vertices || !indices || !argbColors || triangleCount <= 0 || !surfaceFirstTriangles || !surfaceTextureIds || surfaceCount <= 0)
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
    mesh.m_buffer = 0;
    mesh.m_ranges.clear();
    mesh.m_isUsed = fried_mesh::expandInto<Vertex>(vertices, uvs, vertexCount, indices, argbColors, triangleCount, mesh.m_vertices);
    for (int surface = 0; mesh.m_isUsed && surface < surfaceCount; ++surface)
    {
        int first = surfaceFirstTriangles[surface];
        int next = surfaceFirstTriangles[surface + 1];
        if (first < 0 || next < first || next > triangleCount || (surface == 0 && first != 0) || (surface == surfaceCount - 1 && next != triangleCount))
        {
            mesh.m_isUsed = false;
            break;
        }
        if (next == first)
        {
            continue;
        }
        bool isRepeating = false;
        if (uvs && surfaceTextureIds[surface] >= 0)
        {
            for (int corner = first * 3; corner < next * 3 && !isRepeating; ++corner)
            {
                const Vertex &vertex = mesh.m_vertices[(size_t)corner];
                isRepeating = vertex.m_uv[0] < 0.0f || vertex.m_uv[0] > 1.0f || vertex.m_uv[1] < 0.0f || vertex.m_uv[1] > 1.0f;
            }
        }
        if (!mesh.m_ranges.empty() && mesh.m_ranges.back().m_textureId == surfaceTextureIds[surface])
        {
            mesh.m_ranges.back().m_count += (next - first) * 3;
            mesh.m_ranges.back().m_repeats = mesh.m_ranges.back().m_repeats || isRepeating;
        }
        else
        {
            mesh.m_ranges.push_back({first * 3, (next - first) * 3, surfaceTextureIds[surface], isRepeating});
        }
    }
    if (!mesh.m_isUsed)
    {
        mesh.m_vertices.clear();
        mesh.m_ranges.clear();
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
    if (mesh.m_buffer && s_rendererId >= 0 && prepareContext())
    {
        s_gl.m_deleteBuffers(1, &mesh.m_buffer);
    }
    mesh.m_buffer = 0;
    mesh.m_isUsed = false;
    std::vector<Vertex>().swap(mesh.m_vertices);
    mesh.m_ranges.clear();
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

    // Column-major, as GL takes it.
    float modelViewProjection[16];
    for (int row = 0; row < 4; ++row)
    {
        for (int column = 0; column < 4; ++column)
        {
            modelViewProjection[column * 4 + row] = (float)transform.m_clip[row][column];
        }
    }
    float normalMatrix[9];
    for (int row = 0; row < 3; ++row)
    {
        for (int column = 0; column < 3; ++column)
        {
            normalMatrix[column * 3 + row] = transform.m_normal[row][column];
        }
    }

    if (!s_isInMeshMode)
    {
        if (!enterMeshMode(layout, outputHeight))
        {
            return;
        }
    }

    // Meshes of one view share a depth buffer, which starts again each frame
    // and whenever the view changes, as another scene's meshes begin.
    fried_real view[sizeof(s_lastView) / sizeof(fried_real)];
    std::memcpy(view, placement + FRIED_MESH_CAMERA_X, (FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X) * sizeof(fried_real));
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X] = hasCamera ? zoom : 0.0;
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 1] = hasCamera ? cameraX : 0.0;
    view[FRIED_MESH_PLACEMENT_SIZE - FRIED_MESH_CAMERA_X + 2] = hasCamera ? cameraY : 0.0;
    if (!s_isDepthCleared || std::memcmp(view, s_lastView, sizeof(view)) != 0)
    {
        s_gl.m_clear(GL_DEPTH_BUFFER_BIT);
        s_gl.m_uniform3f(s_uniforms.m_light, transform.m_light[0], transform.m_light[1], transform.m_light[2]);
        s_gl.m_uniform1f(s_uniforms.m_ambient, transform.m_ambient);
        std::memcpy(s_lastView, view, sizeof(view));
        s_isDepthCleared = true;
    }

    uploadIfNeeded(mesh);
    s_gl.m_bindBuffer(GL_ARRAY_BUFFER, mesh.m_buffer);
    s_gl.m_uniformMatrix4fv(s_uniforms.m_modelViewProjection, 1, GL_FALSE, modelViewProjection);
    s_gl.m_uniformMatrix3fv(s_uniforms.m_normalMatrix, 1, GL_FALSE, normalMatrix);

    s_gl.m_vertexAttribPointer(s_positionAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void *)offsetof(Vertex, m_position));
    s_gl.m_vertexAttribPointer(s_colorAttribute, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(Vertex), (const void *)offsetof(Vertex, m_color));
    s_gl.m_vertexAttribPointer(s_normalAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void *)offsetof(Vertex, m_normal));
    s_gl.m_vertexAttribPointer(s_uvAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void *)offsetof(Vertex, m_uv));

    for (const Range &range : mesh.m_ranges)
    {
        drawRange(range);
    }
}
