#pragma once

#include <functional>
#include <string>
#include <vector>

// Reads a model from an OBJ or a glTF file, as the formats of other tools keep
// one, and writes it as the compact binary format the engine loads, FRMS. This
// runs on the machine that builds a game, in the asset import tool, and on
// PC, where a game that is edited reads the files it is given as they are.
//
// Everything in the file is flattened into one mesh. Each material becomes a
// surface, painted with a color and an image, and the nodes of a glTF scene
// have their transforms applied to their vertices. The vertices are brought
// to the engine's space, which is left-handed, with a mirror on x that also
// turns the corners of every triangle the other way round, so that triangles
// face the way the engine draws them.
//
// FRMS is little endian. After the four bytes "FRMS", a u16 version of 1, a u16
// of flags that is 0 and a u32 count of surfaces, each surface is:
//
//   u32 vertex count, u32 triangle count
//   u32 flags: bit 0 the surface has texture coordinates, bit 1 its indices
//       are u32 and not u16
//   u32 albedo color as ARGB
//   u32 kind of image: 0 none, 1 a path, 2 a PNG stored in the file
//   for 1 and 2, a u32 length and then that many bytes, padded to a multiple
//       of four: a path is UTF-8 and relative to the folder of the model
//   f32 x, y, z for each vertex
//   f32 u, v for each vertex, if it has them, with (0, 0) at the top left
//   the three indices of each triangle, as u16 or u32, padded to four bytes
namespace fried_model
{
    struct Options
    {
        // Called with an image that is not a file of its own, as a PNG, and a name to
        // call it by. Returns the path of a file it wrote the image to, relative
        // to the model, or an empty string if the image is to be kept inside the
        // model's.
        std::function<std::string(const std::vector<unsigned char> &png, const std::string &name)> m_extract;

        // Leave out the images, and the texture coordinates with them, and paint
        // each surface with its color times the average of its image.
        bool m_stripImages = false;
    };

    struct Result
    {
        std::vector<unsigned char> m_bytes;

        // Every file the model was made of beside itself, as paths.
        std::vector<std::string> m_dependencies;
        std::vector<std::string> m_warnings;
        int m_triangleCount = 0;
        int m_vertexCount = 0;
    };

    // False with a reason in error if the file cannot be read or has no triangles.
    bool convert(const std::string &path, const Options &options, Result *result, std::string *error);
}
