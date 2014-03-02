local util = require "gumbo.util"
local Buffer = util.Buffer
local Indent = util.Indent

local void = {
    area = true,
    base = true,
    basefont = true,
    bgsound = true,
    br = true,
    col = true,
    embed = true,
    frame = true,
    hr = true,
    img = true,
    input = true,
    keygen = true,
    link = true,
    menuitem = true,
    meta = true,
    param = true,
    source = true,
    track = true,
    wbr = true
}

local raw = {
    style = true,
    script = true,
    xmp = true,
    iframe = true,
    noembed = true,
    noframes = true,
    plaintext = true
}

local boolattr = {
    allowfullscreen = true,
    async = true,
    autofocus = true,
    autoplay = true,
    checked = true,
    compact = true,
    controls = true,
    declare = true,
    default = true,
    defer = true,
    disabled = true,
    formnovalidate = true,
    hidden = true,
    inert = true,
    ismap = true,
    itemscope = true,
    loop = true,
    multiple = true,
    multiple = true,
    muted = true,
    nohref = true,
    noresize = true,
    noshade = true,
    novalidate = true,
    nowrap = true,
    open = true,
    readonly = true,
    required = true,
    reversed = true,
    scoped = true,
    seamless = true,
    selected = true,
    sortable = true,
    truespeed = true,
    typemustmatch = true
}

-- Escaping a string consists of running the following steps:
-- 1. Replace any occurrence of the "&" character by the string "&amp;".
-- 2. Replace any occurrences of the U+00A0 NO-BREAK SPACE character by the
--    string "&nbsp;".
-- 3. If the algorithm was invoked in the attribute mode, replace any
--    occurrences of the """ character by the string "&quot;".
-- 4. If the algorithm was not invoked in the attribute mode, replace any
--    occurrences of the "<" character by the string "&lt;", and any
--    occurrences of the ">" character by the string "&gt;".

local escmap = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;"
}

local function escape_text(text)
    return (text:gsub("[&<>]", escmap):gsub("\xC2\xA0", "&nbsp;"))
end

local function escape_attr(text)
    return (text:gsub('[&"]', escmap):gsub("\xC2\xA0", "&nbsp;"))
end

local function wrap(text, indent)
    local limit = 78
    local indent_width = #indent
    local pos = 1 - indent_width
    local function reflow(start, word, stop)
        if stop - pos > limit then
            pos = start - indent_width
            return "\n" .. indent .. word
        else
            return " " .. word
        end
    end
    return indent, text:gsub("%s+()(%S+)()", reflow), "\n"
end

local function to_html(node, buffer, indent_width)
    local buf = buffer or Buffer()
    local get_indent = Indent(indent_width)
    local function serialize(node, depth, parent_tag)
        local indent = get_indent[depth]
        if node.type == "element" then
            local tag = node.tag
            buf:write(indent, "<", tag)
            for index, name, val, ns in node:attr_iter() do
                if ns == "xmlns" and name == "xmlns" then
                    ns = nil
                end
                buf:write(" ", ns and ns..":" or "", name)
                if not boolattr[name] or not (val == "" or val == name) then
                    buf:write('="', escape_attr(val), '"')
                end
            end
            buf:write(">")
            local length = #node
            if void[tag] then
                buf:write("\n")
            elseif length == 0 then
                buf:write("</", tag, ">\n")
            else
                buf:write("\n")
                for i = 1, length do
                    serialize(node[i], depth + 1, node.tag)
                end
                buf:write(indent, "</", tag, ">\n")
            end
        elseif node.type == "text" then
            if raw[parent_tag] then
                buf:write(indent, node.text, "\n")
            else
                buf:write(wrap(escape_text(node.text), indent))
            end
        elseif node.type == "comment" then
            buf:write(indent, "<!--", node.text, "-->\n")
        elseif node.type == "document" then
            if node.has_doctype == true then
                buf:write("<!DOCTYPE ", node.name, ">\n")
            end
            for i = 1, #node do
                serialize(node[i], depth)
            end
        end
    end
    serialize(node, 0)
    return io.type(buf) and true or tostring(buf)
end

return to_html
