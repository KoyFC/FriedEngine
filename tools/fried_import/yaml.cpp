#include "yaml.h"

#include <cctype>
#include <cstdio>
#include <cstdlib>

namespace fried_import
{
    namespace
    {
        const size_t s_none = std::string::npos;

        struct Failure
        {
            size_t m_at;
            std::string m_message;
        };

        bool isBlank(char c)
        {
            return c == ' ' || c == '\t';
        }

        bool isDigit(char c)
        {
            return c >= '0' && c <= '9';
        }

        void appendUtf8(std::string *out, unsigned code)
        {
            if (code < 0x80)
            {
                *out += (char)code;
            }
            else if (code < 0x800)
            {
                *out += (char)(0xC0 | (code >> 6));
                *out += (char)(0x80 | (code & 0x3F));
            }
            else if (code < 0x10000)
            {
                *out += (char)(0xE0 | (code >> 12));
                *out += (char)(0x80 | ((code >> 6) & 0x3F));
                *out += (char)(0x80 | (code & 0x3F));
            }
            else
            {
                *out += (char)(0xF0 | (code >> 18));
                *out += (char)(0x80 | ((code >> 12) & 0x3F));
                *out += (char)(0x80 | ((code >> 6) & 0x3F));
                *out += (char)(0x80 | (code & 0x3F));
            }
        }

        Value makeString(std::string text)
        {
            Value value;
            value.m_kind = Value::Kind::String;
            value.m_string = std::move(text);
            return value;
        }

        // -?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?, a whole number when it has neither a point nor an exponent.
        bool matchNumber(const std::string &text, bool *isInteger)
        {
            size_t i = 0, n = text.size();
            if (i < n && text[i] == '-')
            {
                ++i;
            }
            size_t before = 0;
            while (i < n && isDigit(text[i]))
            {
                ++i;
                ++before;
            }
            if (i == n)
            {
                *isInteger = true;
                return before > 0;
            }
            *isInteger = false;
            bool point = false;
            size_t after = 0;
            if (text[i] == '.')
            {
                point = true;
                ++i;
                while (i < n && isDigit(text[i]))
                {
                    ++i;
                    ++after;
                }
            }
            if (point ? after == 0 : before == 0)
            {
                return false;
            }
            if (i < n && (text[i] == 'e' || text[i] == 'E'))
            {
                ++i;
                if (i < n && (text[i] == '-' || text[i] == '+'))
                {
                    ++i;
                }
                size_t digits = 0;
                while (i < n && isDigit(text[i]))
                {
                    ++i;
                    ++digits;
                }
                if (digits == 0)
                {
                    return false;
                }
            }
            return i == n;
        }

        Value resolvePlain(const std::string &text)
        {
            Value value;
            if (text.empty() || text == "null" || text == "~")
            {
                return value;
            }
            if (text == "true" || text == "false")
            {
                value.m_kind = Value::Kind::Bool;
                value.m_bool = text == "true";
                return value;
            }
            bool isInteger = false;
            if (matchNumber(text, &isInteger))
            {
                value.m_kind = Value::Kind::Number;
                value.m_number = std::strtod(text.c_str(), nullptr);
                value.m_isInteger = isInteger && value.m_number >= -2147483648.0 && value.m_number <= 2147483647.0;
                return value;
            }
            return makeString(text);
        }

        class Parser
        {
        public:
            explicit Parser(const std::string &text)
                : m_text(text)
            {
            }

            Value document()
            {
                if (m_text.compare(0, 3, "\xEF\xBB\xBF") == 0)
                {
                    m_at = 3;
                }
                if (!nextContent(false))
                {
                    return Value();
                }
                if (peek() == '%')
                {
                    fail(m_at, "Fried YAML does not support directives");
                }
                if (isDocumentMarker("---"))
                {
                    m_at += 3;
                    if (!nextContent(false))
                    {
                        return Value();
                    }
                }
                Value root = node();
                if (nextContent(false))
                {
                    if (isDocumentMarker("---") || isDocumentMarker("..."))
                    {
                        fail(m_at, "Fried YAML does not support several documents in a file");
                    }
                    fail(m_at, "this text is not part of the value, which may be a wrong indentation");
                }
                return root;
            }

            std::string where(size_t at) const
            {
                size_t line = 1, start = 0;
                for (size_t i = 0; i < at && i < m_text.size(); ++i)
                {
                    if (m_text[i] == '\n')
                    {
                        ++line;
                        start = i + 1;
                    }
                }
                return std::to_string(line) + ":" + std::to_string(at - start + 1);
            }

        private:
            [[noreturn]] void fail(size_t at, const std::string &message) const
            {
                throw Failure{at, message};
            }

            bool atEnd() const
            {
                return m_at >= m_text.size();
            }

            char peek(size_t offset = 0) const
            {
                return m_at + offset < m_text.size() ? m_text[m_at + offset] : '\0';
            }

            bool blankOrEnd(size_t at) const
            {
                return at >= m_text.size() || m_text[at] == ' ' || m_text[at] == '\t' || m_text[at] == '\n' || m_text[at] == '\r';
            }

            bool isDocumentMarker(const char *marker) const
            {
                return column(m_at) == 0 && m_text.compare(m_at, 3, marker) == 0 && blankOrEnd(m_at + 3);
            }

            size_t column(size_t at) const
            {
                size_t start = at;
                while (start > 0 && m_text[start - 1] != '\n')
                {
                    --start;
                }
                return at - start;
            }

            void skipBlanks()
            {
                while (!atEnd() && isBlank(m_text[m_at]))
                {
                    ++m_at;
                }
            }

            // Moves to the next token, over blank lines and comments, and says whether there is one. A tab may not indent a line of a block.
            bool nextContent(bool inFlow)
            {
                for (;;)
                {
                    size_t blanksStart = m_at;
                    bool tab = false;
                    while (!atEnd() && isBlank(m_text[m_at]))
                    {
                        tab = tab || m_text[m_at] == '\t';
                        ++m_at;
                    }
                    if (atEnd())
                    {
                        return false;
                    }
                    char c = m_text[m_at];
                    if (c == '\n' || c == '\r')
                    {
                        ++m_at;
                        continue;
                    }
                    if (c == '#')
                    {
                        while (!atEnd() && m_text[m_at] != '\n')
                        {
                            ++m_at;
                        }
                        continue;
                    }
                    if (tab && !inFlow && column(blanksStart) == 0)
                    {
                        fail(blanksStart, "a tab cannot indent a line: use spaces");
                    }
                    return true;
                }
            }

            void requireEndOfLine()
            {
                skipBlanks();
                if (!atEnd() && peek() != '\n' && peek() != '\r' && peek() != '#')
                {
                    fail(m_at, "this text comes after a complete value");
                }
            }

            void checkIndicator(char c, size_t at) const
            {
                if (c == '&' || c == '*')
                {
                    fail(at, "Fried YAML does not support anchors and aliases");
                }
                if (c == '!')
                {
                    fail(at, "Fried YAML does not support tags");
                }
                if (c == '|' || c == '>')
                {
                    fail(at, "Fried YAML does not support block scalars: write the text in double quotes with \\n");
                }
                if (c == '?' && blankOrEnd(at + 1))
                {
                    fail(at, "Fried YAML does not support complex keys");
                }
                if (c == '@' || c == '`' || c == '%')
                {
                    fail(at, std::string("the character '") + c + "' cannot start a plain value: put the text in quotes");
                }
            }

            size_t findKeyColon(size_t from) const
            {
                if (from >= m_text.size())
                {
                    return s_none;
                }
                char c = m_text[from];
                size_t i = from;
                if (c == '"' || c == '\'')
                {
                    ++i;
                    while (i < m_text.size() && m_text[i] != '\n')
                    {
                        if (c == '"' && m_text[i] == '\\')
                        {
                            i += 2;
                            continue;
                        }
                        if (m_text[i] == c)
                        {
                            if (c == '\'' && i + 1 < m_text.size() && m_text[i + 1] == '\'')
                            {
                                i += 2;
                                continue;
                            }
                            break;
                        }
                        ++i;
                    }
                    if (i >= m_text.size() || m_text[i] != c)
                    {
                        return s_none;
                    }
                    ++i;
                    while (i < m_text.size() && isBlank(m_text[i]))
                    {
                        ++i;
                    }
                    return i < m_text.size() && m_text[i] == ':' && blankOrEnd(i + 1) ? i : s_none;
                }
                if (c == '{' || c == '[')
                {
                    return s_none;
                }
                for (; i < m_text.size() && m_text[i] != '\n'; ++i)
                {
                    if (m_text[i] == '#' && i > from && isBlank(m_text[i - 1]))
                    {
                        return s_none;
                    }
                    if (m_text[i] == ':' && blankOrEnd(i + 1))
                    {
                        return i;
                    }
                }
                return s_none;
            }

            // A value at the place the block of its line starts, which is a list, a map or a single value.
            Value node()
            {
                size_t col = column(m_at);
                char c = peek();
                if (c == '-' && blankOrEnd(m_at + 1))
                {
                    return sequence(col);
                }
                if (c == '{' || c == '[')
                {
                    Value value = flow();
                    requireEndOfLine();
                    return value;
                }
                if (findKeyColon(m_at) != s_none)
                {
                    return mapping(col);
                }
                Value value = scalar(false);
                requireEndOfLine();
                return value;
            }

            Value sequence(size_t col)
            {
                Value result;
                result.m_kind = Value::Kind::Array;
                for (;;)
                {
                    ++m_at;
                    skipBlanks();
                    Value item;
                    if (atEnd() || peek() == '\n' || peek() == '\r' || peek() == '#')
                    {
                        if (nextContent(false) && column(m_at) > col)
                        {
                            item = node();
                        }
                    }
                    else
                    {
                        item = node();
                    }
                    result.m_array.push_back(std::move(item));
                    if (!nextContent(false))
                    {
                        break;
                    }
                    size_t at = column(m_at);
                    if (at < col || isDocumentMarker("---") || isDocumentMarker("..."))
                    {
                        break;
                    }
                    if (at > col)
                    {
                        fail(m_at, "the indentation does not match the list it follows");
                    }
                    if (!(peek() == '-' && blankOrEnd(m_at + 1)))
                    {
                        break;
                    }
                }
                return result;
            }

            std::string readKey(size_t colon)
            {
                std::string key;
                char c = peek();
                if (c == '"' || c == '\'')
                {
                    key = c == '"' ? doubleQuoted() : singleQuoted();
                    skipBlanks();
                }
                else
                {
                    checkIndicator(c, m_at);
                    key = m_text.substr(m_at, colon - m_at);
                    while (!key.empty() && isBlank(key.back()))
                    {
                        key.pop_back();
                    }
                    if (key.empty())
                    {
                        fail(m_at, "a key is empty");
                    }
                    m_at = colon;
                }
                ++m_at;
                return key;
            }

            Value mapping(size_t col)
            {
                Value result;
                result.m_kind = Value::Kind::Object;
                for (;;)
                {
                    size_t keyAt = m_at;
                    size_t colon = findKeyColon(m_at);
                    if (colon == s_none)
                    {
                        fail(m_at, "a key followed by ':' is expected here");
                    }
                    std::string key = readKey(colon);
                    if (result.m_object.count(key))
                    {
                        fail(keyAt, "the key \"" + key + "\" appears twice");
                    }
                    skipBlanks();
                    Value value;
                    if (!atEnd() && peek() != '\n' && peek() != '\r' && peek() != '#')
                    {
                        value = inlineValue();
                        requireEndOfLine();
                    }
                    else if (nextContent(false))
                    {
                        size_t at = column(m_at);
                        if (at > col)
                        {
                            value = node();
                        }
                        else if (at == col && peek() == '-' && blankOrEnd(m_at + 1))
                        {
                            value = sequence(col);
                        }
                    }
                    result.m_object[key] = std::move(value);
                    if (!nextContent(false))
                    {
                        break;
                    }
                    size_t at = column(m_at);
                    if (at < col || isDocumentMarker("---") || isDocumentMarker("..."))
                    {
                        break;
                    }
                    if (at > col)
                    {
                        fail(m_at, "the indentation does not match the map it follows");
                    }
                }
                return result;
            }

            Value inlineValue()
            {
                char c = peek();
                if (c == '{' || c == '[')
                {
                    return flow();
                }
                if (c == '-' && blankOrEnd(m_at + 1))
                {
                    fail(m_at, "a list cannot start on the line of a key: put it on the next line");
                }
                return scalar(false);
            }

            Value scalar(bool inFlow)
            {
                char c = peek();
                if (c == '"')
                {
                    return makeString(doubleQuoted());
                }
                if (c == '\'')
                {
                    return makeString(singleQuoted());
                }
                checkIndicator(c, m_at);
                size_t start = m_at;
                while (!atEnd() && m_text[m_at] != '\n')
                {
                    char d = m_text[m_at];
                    if (d == '#' && m_at > start && isBlank(m_text[m_at - 1]))
                    {
                        break;
                    }
                    if (inFlow && (d == ',' || d == ']' || d == '}'))
                    {
                        break;
                    }
                    ++m_at;
                }
                std::string text = m_text.substr(start, m_at - start);
                while (!text.empty() && (isBlank(text.back()) || text.back() == '\r'))
                {
                    text.pop_back();
                }
                return resolvePlain(text);
            }

            unsigned hex4()
            {
                unsigned code = 0;
                for (int i = 0; i < 4; ++i)
                {
                    char c = peek();
                    if (!std::isxdigit((unsigned char)c))
                    {
                        fail(m_at, "\\u needs four hexadecimal digits");
                    }
                    code = code * 16 + (isDigit(c) ? c - '0' : (std::tolower(c) - 'a' + 10));
                    ++m_at;
                }
                return code;
            }

            std::string doubleQuoted()
            {
                size_t start = m_at++;
                std::string out;
                for (;;)
                {
                    if (atEnd() || peek() == '\n')
                    {
                        fail(start, "a string in double quotes is not closed on its line");
                    }
                    char c = m_text[m_at++];
                    if (c == '"')
                    {
                        return out;
                    }
                    if (c != '\\')
                    {
                        out += c;
                        continue;
                    }
                    char e = peek();
                    ++m_at;
                    switch (e)
                    {
                    case '"': out += '"'; break;
                    case '\\': out += '\\'; break;
                    case '/': out += '/'; break;
                    case 'b': out += '\b'; break;
                    case 'f': out += '\f'; break;
                    case 'n': out += '\n'; break;
                    case 'r': out += '\r'; break;
                    case 't': out += '\t'; break;
                    case 'u':
                    {
                        unsigned code = hex4();
                        if (code >= 0xD800 && code < 0xDC00)
                        {
                            if (peek() != '\\' || peek(1) != 'u')
                            {
                                fail(m_at, "a high surrogate needs the low one after it");
                            }
                            m_at += 2;
                            unsigned low = hex4();
                            if (low < 0xDC00 || low > 0xDFFF)
                            {
                                fail(m_at, "a high surrogate needs the low one after it");
                            }
                            code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
                        }
                        else if (code >= 0xDC00 && code <= 0xDFFF)
                        {
                            fail(m_at, "a low surrogate comes without its high one");
                        }
                        appendUtf8(&out, code);
                        break;
                    }
                    default:
                        fail(m_at - 1, "this escape is unknown");
                    }
                }
            }

            std::string singleQuoted()
            {
                size_t start = m_at++;
                std::string out;
                for (;;)
                {
                    if (atEnd() || peek() == '\n')
                    {
                        fail(start, "a string in single quotes is not closed on its line");
                    }
                    char c = m_text[m_at++];
                    if (c == '\'')
                    {
                        if (peek() == '\'')
                        {
                            out += '\'';
                            ++m_at;
                            continue;
                        }
                        return out;
                    }
                    out += c;
                }
            }

            void skipFlowSpace(size_t openedAt)
            {
                if (!nextContent(true))
                {
                    fail(openedAt, "this collection is not closed");
                }
            }

            Value flow()
            {
                size_t openedAt = m_at;
                bool isObject = peek() == '{';
                char close = isObject ? '}' : ']';
                ++m_at;
                Value result;
                result.m_kind = isObject ? Value::Kind::Object : Value::Kind::Array;
                skipFlowSpace(openedAt);
                if (peek() == close)
                {
                    ++m_at;
                    return result;
                }
                for (;;)
                {
                    if (isObject)
                    {
                        size_t keyAt = m_at;
                        std::string key;
                        char c = peek();
                        if (c == '"' || c == '\'')
                        {
                            key = c == '"' ? doubleQuoted() : singleQuoted();
                        }
                        else
                        {
                            checkIndicator(c, m_at);
                            size_t start = m_at;
                            while (!atEnd() && m_text[m_at] != '\n' && !(m_text[m_at] == ':' && blankOrEnd(m_at + 1)) && m_text[m_at] != ',' && m_text[m_at] != '}')
                            {
                                ++m_at;
                            }
                            key = m_text.substr(start, m_at - start);
                            while (!key.empty() && isBlank(key.back()))
                            {
                                key.pop_back();
                            }
                            if (key.empty())
                            {
                                fail(keyAt, "a key is empty");
                            }
                        }
                        skipFlowSpace(openedAt);
                        if (peek() != ':')
                        {
                            fail(m_at, "a ':' is missing after the key");
                        }
                        ++m_at;
                        skipFlowSpace(openedAt);
                        if (result.m_object.count(key))
                        {
                            fail(keyAt, "the key \"" + key + "\" appears twice");
                        }
                        result.m_object[key] = flowValue();
                    }
                    else
                    {
                        result.m_array.push_back(flowValue());
                    }
                    skipFlowSpace(openedAt);
                    if (peek() == ',')
                    {
                        ++m_at;
                        skipFlowSpace(openedAt);
                        if (peek() == close)
                        {
                            fail(m_at, "a comma cannot come before the end of a collection");
                        }
                        continue;
                    }
                    if (peek() == close)
                    {
                        ++m_at;
                        return result;
                    }
                    fail(m_at, std::string("a ',' or '") + close + "' is missing");
                }
            }

            Value flowValue()
            {
                char c = peek();
                if (c == '{' || c == '[')
                {
                    return flow();
                }
                return scalar(true);
            }

            const std::string &m_text;
            size_t m_at = 0;
        };

        void writeJsonString(const std::string &text, std::string *out)
        {
            *out += '"';
            for (unsigned char c : text)
            {
                switch (c)
                {
                case '"': *out += "\\\""; break;
                case '\\': *out += "\\\\"; break;
                case '\n': *out += "\\n"; break;
                case '\r': *out += "\\r"; break;
                case '\t': *out += "\\t"; break;
                default:
                    if (c < 0x20)
                    {
                        char buffer[8];
                        std::snprintf(buffer, sizeof buffer, "\\u%04x", c);
                        *out += buffer;
                    }
                    else
                    {
                        *out += (char)c;
                    }
                }
            }
            *out += '"';
        }

        void writeJson(const Value &value, std::string *out)
        {
            switch (value.m_kind)
            {
            case Value::Kind::Null: *out += "null"; break;
            case Value::Kind::Bool: *out += value.m_bool ? "true" : "false"; break;
            case Value::Kind::Number:
            {
                char buffer[40];
                if (value.m_isInteger)
                {
                    std::snprintf(buffer, sizeof buffer, "%d", (int)value.m_number);
                }
                else
                {
                    std::snprintf(buffer, sizeof buffer, "%.17g", value.m_number);
                }
                *out += buffer;
                break;
            }
            case Value::Kind::String: writeJsonString(value.m_string, out); break;
            case Value::Kind::Array:
                *out += '[';
                for (size_t i = 0; i < value.m_array.size(); ++i)
                {
                    *out += i ? "," : "";
                    writeJson(value.m_array[i], out);
                }
                *out += ']';
                break;
            case Value::Kind::Object:
            {
                *out += '{';
                bool first = true;
                for (const auto &pair : value.m_object)
                {
                    *out += first ? "" : ",";
                    first = false;
                    writeJsonString(pair.first, out);
                    *out += ':';
                    writeJson(pair.second, out);
                }
                *out += '}';
                break;
            }
            }
        }
    }

    bool parseYaml(const std::string &text, Value *value, std::string *error)
    {
        Parser parser(text);
        try
        {
            *value = parser.document();
            return true;
        }
        catch (const Failure &failure)
        {
            *error = parser.where(failure.m_at) + ": " + failure.m_message;
            return false;
        }
    }

    std::string toJson(const Value &value)
    {
        std::string out;
        writeJson(value, &out);
        return out;
    }
}
