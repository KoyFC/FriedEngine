#pragma once

#include <string>
#include <vector>

namespace fried_import
{
    // Writes a TrueType font again without the tables the engine's software text never reads: the variation tables of a variable font (gvar, HVAR, MVAR, STAT, fvar, avar), which can be most of its bytes, and the glyph substitution and definition tables (GSUB, GDEF). Outlines, metrics, character map and kerning are copied as they are, so every glyph draws the same. A DS reads a whole font file into RAM, which is why the file is made small.
    // Returns false, with the reason, for a file that is not a single TrueType font, which is then copied as it is.
    bool stripFontTables(const std::vector<unsigned char> &file, std::vector<unsigned char> *out, std::string *error);
}
