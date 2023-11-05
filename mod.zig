//! Parser for Extensible Markup Language (XML)
//! https://www.w3.org/TR/xml/
// https://www.w3.org/XML/Test/xmlconf-20020606.htm

const std = @import("std");
const string = []const u8;
const extras = @import("extras");
const Parser = @import("./Parser.zig");

//
//

pub fn parse(alloc: std.mem.Allocator, path: string, inreader: std.fs.File.Reader) !Document {
    var bufread = std.io.bufferedReader(inreader);
    var counter = std.io.countingReader(bufread.reader());
    const anyreader = extras.AnyReader.from(counter.reader());
    var ourreader = Parser{ .any = anyreader };
    errdefer ourreader.extras.deinit(alloc);
    errdefer ourreader.string_bytes.deinit(alloc);
    errdefer ourreader.strings_map.deinit(alloc);

    return parseDocument(alloc, &ourreader) catch |err| switch (err) {
        error.XmlMalformed => {
            std.log.err("{s}:{d}:{d}: {d}'{s}'", .{ path, ourreader.line, ourreader.col -| ourreader.amt, ourreader.amt, ourreader.buf });
            if (@errorReturnTrace()) |trace| std.debug.dumpStackTrace(trace.*);
            return err;
        },
        else => |e| @as(@TypeOf(counter.reader()).Error, @errSetCast(e)),
    };
}

/// document   ::=   prolog element Misc*
fn parseDocument(alloc: std.mem.Allocator, p: *Parser) anyerror!Document {
    _ = try parseProlog(alloc, p);
    _ = try parseElement(alloc, p);
    while (true) try parseMisc(alloc, p) orelse break;

    defer p.strings_map.deinit(alloc);
    return .{
        .allocator = alloc,
        .extras = try p.extras.toOwnedSlice(alloc),
        .string_bytes = try p.string_bytes.toOwnedSlice(alloc),
    };
}

/// prolog   ::=   XMLDecl? Misc* (doctypedecl Misc*)?
fn parseProlog(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    _ = try parseXMLDecl(alloc, p) orelse {};
    while (true) try parseMisc(alloc, p) orelse break;
    try parseDoctypeDecl(alloc, p) orelse return;
    while (true) try parseMisc(alloc, p) orelse break;
}

/// element   ::=   EmptyElemTag
/// element   ::=   STag content ETag
///
/// EmptyElemTag   ::=   '<' Name (S Attribute)* S? '/>'
/// STag           ::=   '<' Name (S Attribute)* S? '>'
fn parseElement(alloc: std.mem.Allocator, p: *Parser) anyerror!?Element {
    if (try p.peek("</")) return null;
    if (try p.peek("<!")) return null;
    try p.eat("<") orelse return null;
    const name = try parseName(alloc, p) orelse return error.XmlMalformed;
    while (true) {
        try parseS(p) orelse {};
        try parseAttribute(alloc, p) orelse break;
    }
    try parseS(p) orelse {};
    if (try p.eat("/>")) |_| return .{
        .tag_name = name,
    };
    try p.eat(">") orelse return error.XmlMalformed;

    try parseContent(alloc, p) orelse return error.XmlMalformed;
    try parseETag(alloc, p, name) orelse return error.XmlMalformed;
    return .{
        .tag_name = name,
    };
}

/// Misc   ::=   Comment | PI | S
fn parseMisc(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try parseComment(p) orelse {
        _ = try parsePI(alloc, p) orelse {
            try parseS(p) orelse {
                return null;
            };
        };
    };
}

/// XMLDecl   ::=   '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
fn parseXMLDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?XMLDecl {
    try p.eat("<?xml") orelse return null;
    const version_info = try parseVersionInfo(p) orelse return error.XmlMalformed;
    const encoding = try parseEncodingDecl(alloc, p);
    const standalone = try parseSDDecl(p);
    try parseS(p) orelse {};
    try p.eat("?>") orelse return error.XmlMalformed;
    if (version_info[0] != 1) return error.XmlMalformed; // version should be 1.0
    if (version_info[1] != 0) return error.XmlMalformed; // version should be 1.0
    return .{
        .encoding = encoding,
        .standalone = standalone,
    };
}

/// doctypedecl   ::=   '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
fn parseDoctypeDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("<!DOCTYPE") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse {};
    _ = try parseExternalOrPublicID(alloc, p, false) orelse {};
    try parseS(p) orelse {};
    if (try p.eat("[")) |_| {
        try parseIntSubset(alloc, p) orelse return error.XmlMalformed;
        try p.eat("]") orelse return error.XmlMalformed;
        try parseS(p) orelse {};
    }
    try p.eat(">") orelse return error.XmlMalformed;
}

/// content   ::=   CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
fn parseContent(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    _ = try parseCharData(alloc, p) orelse {};
    while (true) {
        if (try parsePI(alloc, p)) |_| {
            _ = try parseCharData(alloc, p) orelse {};
            continue;
        }
        if (try parseElement(alloc, p)) |_| {
            _ = try parseCharData(alloc, p) orelse {};
            continue;
        }
        if (try parseReference(alloc, p)) |_| {
            _ = try parseCharData(alloc, p) orelse {};
            continue;
        }
        if (try parseCDSect(alloc, p)) |_| {
            _ = try parseCharData(alloc, p) orelse {};
            continue;
        }
        if (try parseComment(p)) |_| {
            _ = try parseCharData(alloc, p) orelse {};
            continue;
        }
        break;
    }
}

/// ETag   ::=   '</' Name S? '>'
fn parseETag(alloc: std.mem.Allocator, p: *Parser, expected_name: StringIndex) anyerror!?void {
    try p.eat("</") orelse return null;
    const name = try parseName(alloc, p) orelse return error.XmlMalformed;
    if (name != expected_name) return error.XmlMalformed;
    try parseS(p) orelse {};
    try p.eat(">") orelse return error.XmlMalformed;
}

/// Comment   ::=   '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
fn parseComment(p: *Parser) anyerror!?void {
    try p.eat("<!--") orelse return null;
    while (true) {
        if (try p.eat("-->")) |_| break;
        _ = try parseChar(p) orelse return error.XmlMalformed;
    }
}

/// PI   ::=   '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
fn parsePI(alloc: std.mem.Allocator, p: *Parser) anyerror!?PI {
    try p.eat("<?") orelse return null;
    const target = try parsePITarget(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse {};

    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();
    while (true) {
        if (try p.eat("?>")) |_| break;
        const cp = try parseChar(p) orelse return error.XmlMalformed;
        try addUCPtoList(&list, cp);
    }
    return .{
        .target = target,
        .rest = try p.addStr(alloc, list.items),
    };
}

/// S   ::=   (#x20 | #x9 | #xD | #xA)+
fn parseS(p: *Parser) anyerror!?void {
    var i: usize = 0;
    while (true) : (i += 1) {
        if (try p.eatAny(&.{ 0x20, 0x09, 0x0D, 0x0A })) |_| continue; // space, \t, \r, \n
        if (i == 0) return null;
        break;
    }
}

/// VersionInfo   ::=   S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
fn parseVersionInfo(p: *Parser) anyerror!?[2]u8 {
    try parseS(p) orelse return null;
    try p.eat("version") orelse return error.XmlMalformed;
    try parseEq(p) orelse return error.XmlMalformed;
    const q = try p.eatQuoteS() orelse return error.XmlMalformed;
    const vers = try parseVersionNum(p) orelse return error.XmlMalformed;
    try p.eatQuoteE(q) orelse return error.XmlMalformed;
    return vers;
}

/// EncodingDecl   ::=   S 'encoding' Eq ('"' EncName '"' | "'" EncName "'" )
fn parseEncodingDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    try parseS(p) orelse {};
    try p.eat("encoding") orelse return null;
    try parseEq(p) orelse return error.XmlMalformed;
    const q = try p.eatQuoteS() orelse return error.XmlMalformed;
    const ename = try parseEncName(alloc, p) orelse return error.XmlMalformed;
    try p.eatQuoteE(q) orelse return error.XmlMalformed;
    return ename;
}

/// SDDecl   ::=   S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"'))
fn parseSDDecl(p: *Parser) anyerror!?Standalone {
    try parseS(p) orelse {};
    try p.eat("standalone") orelse return null;
    try parseEq(p) orelse return error.XmlMalformed;
    const q = try p.eatQuoteS() orelse return error.XmlMalformed;
    const sd = try p.eatEnum(Standalone) orelse return error.XmlMalformed;
    try p.eatQuoteE(q) orelse return error.XmlMalformed;
    return sd;
}

/// Name   ::=   NameStartChar (NameChar)*
fn parseName(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    try addUCPtoList(&list, try parseNameStartChar(p) orelse return null);
    while (true) {
        try addUCPtoList(&list, try parseNameChar(p) orelse break);
    }
    return try p.addStr(alloc, list.items);
}

/// ExternalID   ::=   'SYSTEM' S SystemLiteral
/// PublicID     ::=   'PUBLIC' S PubidLiteral
/// ExternalID   ::=   'PUBLIC' S PubidLiteral S SystemLiteral
fn parseExternalOrPublicID(alloc: std.mem.Allocator, p: *Parser, comptime allow_public: bool) anyerror!?ID {
    try p.eat("SYSTEM") orelse {
        try p.eat("PUBLIC") orelse return null;
        try parseS(p) orelse return error.XmlMalformed;
        const pubid_lit = try parsePubidLiteral(alloc, p) orelse return error.XmlMalformed;
        try parseS(p) orelse return if (allow_public) .{ .public = pubid_lit } else error.XmlMalformed;
        const sys_lit = try parseSystemLiteral(alloc, p) orelse return error.XmlMalformed;
        return .{ .external = .{ .public = .{ pubid_lit, sys_lit } } };
    };
    try parseS(p) orelse return error.XmlMalformed;
    const sys_lit = try parseSystemLiteral(alloc, p) orelse return error.XmlMalformed;
    return .{ .external = .{ .system = sys_lit } };
}

/// intSubset   ::=   (markupdecl | DeclSep)*
fn parseIntSubset(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try parseMarkupDecl(alloc, p) orelse try parseDeclSep(alloc, p) orelse return null;
    while (true) {
        try parseMarkupDecl(alloc, p) orelse try parseDeclSep(alloc, p) orelse break;
    }
}

/// Attribute   ::=   Name Eq AttValue
fn parseAttribute(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    _ = try parseName(alloc, p) orelse return null;
    try parseEq(p) orelse return error.XmlMalformed;
    try parseAttValue(alloc, p) orelse return error.XmlMalformed;
}

/// CharData   ::=   [^<&]* - ([^<&]* ']]>' [^<&]*)
fn parseCharData(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    var i: usize = 0;
    while (true) : (i += 1) {
        if (try p.peek("]]>")) break;
        if (try p.eatAnyNot("<&")) |c| {
            try list.append(c);
            continue;
        }
        if (i == 0) return null;
        break;
    }
    return try p.addStr(alloc, list.items);
}

/// Reference   ::=   EntityRef | CharRef
fn parseReference(alloc: std.mem.Allocator, p: *Parser) anyerror!?Reference {
    const cp = try parseCharRef(p) orelse {
        _ = try parseEntityRef(alloc, p) orelse {
            return null;
        };
        // TODO:
        return .{ .entity = {} };
    };
    return .{ .char = cp };
}

/// CDSect   ::=   CDStart CData CDEnd
fn parseCDSect(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    try parseCDStart(p) orelse return null;
    const text = try parseCData(alloc, p) orelse return error.XmlMalformed;
    try parseCDEnd(p) orelse return error.XmlMalformed;
    return text;
}

/// PITarget   ::=   Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
fn parsePITarget(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    if (try p.peek("xml ")) return null;
    if (try p.peek("XML ")) return null;
    return try parseName(alloc, p) orelse return null;
}

/// Char   ::=   #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]	/* any Unicode character, excluding the surrogate blocks, FFFE, and FFFF. */
fn parseChar(p: *Parser) anyerror!?u21 {
    try p.peekAmt(3) orelse return null;
    if (std.unicode.utf8Decode(p.buf[0..1]) catch null) |cp| {
        p.shiftLAmt(1);
        return cp;
    }
    if (std.unicode.utf8Decode(p.buf[0..2]) catch null) |cp| {
        p.shiftLAmt(2);
        return cp;
    }
    if (std.unicode.utf8Decode(p.buf[0..3]) catch null) |cp| {
        p.shiftLAmt(3);
        return cp;
    }
    return null;
}

/// Eq   ::=   S? '=' S?
fn parseEq(p: *Parser) anyerror!?void {
    try parseS(p) orelse {};
    try p.eat("=") orelse return null;
    try parseS(p) orelse {};
}

/// VersionNum   ::=   '1.' [0-9]+
fn parseVersionNum(p: *Parser) anyerror!?[2]u8 {
    var vers = [2]u8{ 1, 0 };
    try p.eat("1.") orelse return null;
    var i: usize = 0;
    while (true) : (i += 1) {
        if (try p.eatRange('0', '9')) |c| {
            vers[1] *= 10;
            vers[1] += c - '0';
            continue;
        }
        if (i == 0) return null;
        break;
    }
    return vers;
}

/// EncName   ::=   [A-Za-z] ([A-Za-z0-9._] | '-')*
fn parseEncName(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    const b = try p.eatRange('A', 'Z') orelse try p.eatRange('a', 'z') orelse return null;
    try list.append(b);
    while (true) {
        const c = try p.eatRange('A', 'Z') orelse
            try p.eatRange('a', 'z') orelse
            try p.eatRange('0', '9') orelse
            try p.eatByte('.') orelse
            try p.eatByte('_') orelse
            try p.eatByte('-') orelse
            break;
        try list.append(c);
    }
    return try p.addStr(alloc, list.items);
}

/// NameStartChar   ::=   ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
fn parseNameStartChar(p: *Parser) anyerror!?u21 {
    if (try p.eatByte(':')) |b| return b;
    if (try p.eatRange('A', 'Z')) |b| return b;
    if (try p.eatByte('_')) |b| return b;
    if (try p.eatRange('a', 'z')) |b| return b;
    if (try p.eatRangeM(0xC0, 0xD6)) |b| return b;
    if (try p.eatRangeM(0xD8, 0xF6)) |b| return b;
    if (try p.eatRangeM(0xF8, 0x2FF)) |b| return b;
    if (try p.eatRangeM(0x370, 0x37D)) |b| return b;
    if (try p.eatRangeM(0x37F, 0x1FFF)) |b| return b;
    if (try p.eatRangeM(0x200C, 0x200D)) |b| return b;
    if (try p.eatRangeM(0x2070, 0x218F)) |b| return b;
    if (try p.eatRangeM(0x2C00, 0x2FEF)) |b| return b;
    if (try p.eatRangeM(0x3001, 0xD7FF)) |b| return b;
    if (try p.eatRangeM(0xF900, 0xFDCF)) |b| return b;
    if (try p.eatRangeM(0xFDF0, 0xFFFD)) |b| return b;
    if (try p.eatRangeM(0x10000, 0xEFFFF)) |b| return b;
    return null;
}

/// NameChar   ::=   NameStartChar | "-" | "." | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
fn parseNameChar(p: *Parser) anyerror!?u21 {
    if (try p.eatByte('-')) |b| return b;
    if (try p.eatByte('.')) |b| return b;
    if (try p.eatRange('0', '9')) |b| return b;
    if (try parseNameStartChar(p)) |b| return b;
    if (try p.eatByte(0xB7)) |b| return b;
    if (try p.eatRangeM(0x0300, 0x036F)) |b| return b;
    if (try p.eatRangeM(0x203F, 0x2040)) |b| return b;
    return null;
}

/// SystemLiteral   ::=   ('"' [^"]* '"')
/// SystemLiteral   ::=   ("'" [^']* "'")
fn parseSystemLiteral(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    const q = try p.eatQuoteS() orelse return null;
    while (true) {
        if (try p.eatByte(q)) |_| break;
        try p.peekAmt(1) orelse return error.XmlMalformed;
        const c = try p.eatByte(p.buf[0]) orelse return error.XmlMalformed;
        try list.append(c);
    }
    return try p.addStr(alloc, list.items);
}

/// PubidLiteral   ::=   '"' PubidChar* '"'
/// PubidLiteral   ::=   "'" (PubidChar - "'")* "'"
fn parsePubidLiteral(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    const q = try p.eatQuoteS() orelse return null;
    while (true) {
        if (try p.eatQuoteE(q)) |_| break;
        const c = try parsePubidChar(p) orelse break;
        try addUCPtoList(&list, c);
    }
    return try p.addStr(alloc, list.items);
}

/// markupdecl   ::=   elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment
fn parseMarkupDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    if (try parseElementDecl(alloc, p)) |_| return;
    if (try parseAttlistDecl(alloc, p)) |_| return;
    if (try parseEntityDecl(alloc, p)) |_| return;
    if (try parseNotationDecl(alloc, p)) |_| return;
    if (try parsePI(alloc, p)) |_| return;
    if (try parseComment(p)) |_| return;
    return null;
}

/// DeclSep   ::=   PEReference | S
fn parseDeclSep(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    if (try parsePEReference(alloc, p)) |_| return;
    if (try parseS(p)) |_| return;
    return null;
}

/// AttValue   ::=   '"' ([^<&"] | Reference)* '"'
/// AttValue   ::=   "'" ([^<&'] | Reference)* "'"
fn parseAttValue(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    const q = try p.eatQuoteS() orelse return null;
    while (true) {
        if (try p.eatQuoteE(q)) |_| break;
        if (try p.eatAnyNot(&.{ '<', '&', q })) |_| continue;
        if (try parseReference(alloc, p)) |_| continue;
        unreachable;
    }
}

/// EntityRef   ::=   '&' Name ';'
fn parseEntityRef(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("&") orelse return null;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try p.eat(";") orelse return error.XmlMalformed;
}

/// CharRef   ::=   '&#' [0-9]+ ';'
/// CharRef   ::=   '&#x' [0-9a-fA-F]+ ';'
fn parseCharRef(p: *Parser) anyerror!?u21 {
    try p.eat("&#x") orelse {
        try p.eat("&#") orelse return null;
        var i: usize = 0;
        var d: u21 = 0;
        while (true) : (i += 1) {
            if (try p.eatRange('0', '9')) |c| {
                d *= 10;
                d += c - '0';
                continue;
            }
            if (i == 0) return error.XmlMalformed;
            break;
        }
        try p.eat(";") orelse return error.XmlMalformed;
        return d;
    };
    var i: usize = 0;
    var d: u21 = 0;
    while (true) : (i += 1) {
        if (try p.eatRange('0', '9')) |c| {
            d *= 16;
            d += c - '0';
            continue;
        }
        if (try p.eatRange('a', 'f')) |c| {
            d *= 16;
            d += c - 'a' + 10;
            continue;
        }
        if (try p.eatRange('A', 'F')) |c| {
            d *= 16;
            d += c - 'A' + 10;
            continue;
        }
        if (i == 0) return error.XmlMalformed;
        break;
    }
    try p.eat(";") orelse return error.XmlMalformed;
    return d;
}

/// CDStart   ::=   '<![CDATA['
fn parseCDStart(p: *Parser) anyerror!?void {
    try p.eat("<![CDATA[") orelse return null;
}

/// CData   ::=   (Char* - (Char* ']]>' Char*))
fn parseCData(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    while (true) {
        if (try p.peek("]]>")) break;
        const c = try parseChar(p) orelse return error.XmlMalformed;
        try addUCPtoList(&list, c);
    }
    return try p.addStr(alloc, list.items);
}

/// CDEnd   ::=   ']]>'
fn parseCDEnd(p: *Parser) anyerror!?void {
    return p.eat("]]>");
}

/// PubidChar   ::=   #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
fn parsePubidChar(p: *Parser) anyerror!?u21 {
    if (try p.eatByte(0x20)) |b| return b;
    if (try p.eatByte(0x0D)) |b| return b;
    if (try p.eatByte(0x0A)) |b| return b;
    if (try p.eatRange('a', 'z')) |b| return b;
    if (try p.eatRange('A', 'Z')) |b| return b;
    if (try p.eatRange('0', '9')) |b| return b;
    if (try p.eatAny("-'()+,./:=?;!*#@$_%")) |b| return b;
    return null;
}

/// elementdecl   ::=   '<!ELEMENT' S Name S contentspec S? '>'
fn parseElementDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("<!ELEMENT") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse return error.XmlMalformed;
    try parseContentSpec(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse {};
    try p.eat(">") orelse return error.XmlMalformed;
}

/// AttlistDecl   ::=   '<!ATTLIST' S Name AttDef* S? '>'
fn parseAttlistDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("<!ATTLIST") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    while (true) try parseAttDef(alloc, p) orelse break;
    try parseS(p) orelse {};
    try p.eat(">") orelse return error.XmlMalformed;
}

/// EntityDecl   ::=   GEDecl | PEDecl
fn parseEntityDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("<!ENTITY") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    if (try parseGEDecl(alloc, p)) |_| return;
    if (try parsePEDecl(alloc, p)) |_| return;
    return null;
}

/// NotationDecl   ::=   '<!NOTATION' S Name S (ExternalID | PublicID) S? '>'
fn parseNotationDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("<!NOTATION") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseExternalOrPublicID(alloc, p, true) orelse return error.XmlMalformed;
    try parseS(p) orelse {};
    try p.eat(">") orelse return error.XmlMalformed;
}

/// PEReference   ::=   '%' Name ';'
fn parsePEReference(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("%") orelse return null;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try p.eat(";") orelse return error.XmlMalformed;
}

/// contentspec   ::=   'EMPTY' | 'ANY' | Mixed | children
fn parseContentSpec(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    if (try p.eat("EMPTY")) |_| return;
    if (try p.eat("ANY")) |_| return;

    try p.eat("(") orelse return null;
    try parseS(p) orelse {};
    if (try parseMixed(alloc, p)) |_| return;
    if (try parseChildren(alloc, p)) |_| return;
    return null;
}

/// AttDef   ::=   S Name S AttType S DefaultDecl
fn parseAttDef(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try parseS(p) orelse return null;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseAttType(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse return error.XmlMalformed;
    try parseDefaultDecl(alloc, p) orelse return error.XmlMalformed;
}

/// GEDecl   ::=   '<!ENTITY' S Name S EntityDef S? '>'
fn parseGEDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    _ = try parseName(alloc, p) orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    try parseEntityDef(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse {};
    try p.eat(">") orelse return error.XmlMalformed;
}

/// PEDecl   ::=   '<!ENTITY' S '%' S Name S PEDef S? '>'
fn parsePEDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try p.eat("%") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    _ = try parseName(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse return error.XmlMalformed;
    try parsePEDef(alloc, p) orelse return error.XmlMalformed;
    try parseS(p) orelse {};
    try p.eat(">") orelse return error.XmlMalformed;
}

/// Mixed   ::=   '(' S? '#PCDATA' (S? '|' S? Name)* S? ')*'
/// Mixed   ::=   '(' S? '#PCDATA' S? ')'
fn parseMixed(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringListIndex {
    try p.eat("#PCDATA") orelse return null;
    try parseS(p) orelse {};
    if (try p.eat(")")) |_| return .empty;

    var list = std.ArrayList(StringIndex).init(alloc);
    defer list.deinit();
    while (true) {
        try parseS(p) orelse {};
        try p.eat("|") orelse break;
        try parseS(p) orelse {};
        try list.append(try parseName(alloc, p) orelse return error.XmlMalformed);
    }
    try p.eat(")*") orelse return error.XmlMalformed;
    return try p.addStrList(alloc, list.items);
}

/// children   ::=   (choice | seq) ('?' | '*' | '+')?
fn parseChildren(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    try parseChoiceOrSeq(alloc, p, true, null) orelse return null;
    _ = try p.eatAny(&.{ '?', '*', '+' }) orelse {};
}

/// AttType   ::=   StringType | TokenizedType | EnumeratedType
fn parseAttType(alloc: std.mem.Allocator, p: *Parser) anyerror!?AttType {
    if (try parseStringType(p)) |_| return .{ .string = {} };
    if (try parseTokenizedType(p)) |t| return .{ .tokenized = t };
    if (try parseEnumeratedType(alloc, p)) |t| return .{ .enumerated = t };
    return null;
}

/// DefaultDecl   ::=   '#REQUIRED' | '#IMPLIED'
/// DefaultDecl   ::=   (('#FIXED' S)? AttValue)
fn parseDefaultDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    if (try p.eat("#REQUIRED")) |_| return;
    if (try p.eat("#IMPLIED")) |_| return;

    if (try p.eat("#FIXED")) |_| {
        try parseS(p) orelse return error.XmlMalformed;
    }
    try parseAttValue(alloc, p) orelse return error.XmlMalformed;
}

/// EntityDef   ::=   EntityValue | (ExternalID NDataDecl?)
fn parseEntityDef(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    return try parseEntityValue(alloc, p) orelse {
        _ = try parseExternalOrPublicID(alloc, p, false) orelse return null;
        _ = try parseNDataDecl(alloc, p) orelse {};
        return;
    };
}

/// PEDef   ::=   EntityValue | ExternalID
fn parsePEDef(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    if (try parseExternalOrPublicID(alloc, p, false)) |_| return;
    if (try parseEntityValue(alloc, p)) |_| return;
    return null;
}

/// choice   ::=   '(' S? cp ( S? '|' S? cp )+ S? ')'
/// seq      ::=   '(' S? cp ( S? ',' S? cp )* S? ')'
/// cp       ::=   (Name | choice | seq) ('?' | '*' | '+')?
fn parseChoiceOrSeq(alloc: std.mem.Allocator, p: *Parser, started: bool, sep_start: ?u8) anyerror!?void {
    if (!started) {
        try p.eat("(") orelse return null;
        try parseS(p) orelse {};
        try parseCp(alloc, p, sep_start) orelse return error.XmlMalformed;
    } else {
        try parseCp(alloc, p, sep_start) orelse return null;
    }

    try parseS(p) orelse {};
    if (try p.eat(")")) |_| return;

    const sep = sep_start orelse try p.eatAny(&.{ '|', ',' }) orelse return error.XmlMalformed;
    if (sep_start != null) _ = try p.eatByte(sep);
    while (true) {
        try parseS(p) orelse {};
        try parseCp(alloc, p, sep) orelse break;
        try parseS(p) orelse {};
        _ = try p.eatByte(sep) orelse break;
    }
    try parseS(p) orelse {};
    try p.eat(")") orelse return error.XmlMalformed;
}

/// StringType   ::=   'CDATA'
fn parseStringType(p: *Parser) anyerror!?void {
    return p.eat("CDATA");
}

/// TokenizedType   ::=   'ID' | 'IDREF' | 'IDREFS' | 'ENTITY' | 'ENTITIES' | 'NMTOKEN' | 'NMTOKENS'
fn parseTokenizedType(p: *Parser) anyerror!?TokenizedType {
    return p.eatEnum(TokenizedType);
}

/// EnumeratedType   ::=   NotationType | Enumeration
fn parseEnumeratedType(alloc: std.mem.Allocator, p: *Parser) anyerror!?EnumeratedType {
    if (try parseNotationType(alloc, p)) |idx| return .{ .notation_type = idx };
    if (try parseEnumeration(alloc, p)) |idx| return .{ .enumeration = idx };
    return null;
}

/// EntityValue   ::=   '"' ([^%&"] | PEReference | Reference)* '"'
/// EntityValue   ::=   "'" ([^%&'] | PEReference | Reference)* "'"
fn parseEntityValue(alloc: std.mem.Allocator, p: *Parser) anyerror!?void {
    const q = try p.eatQuoteS() orelse return null;
    while (true) {
        if (try p.eatQuoteE(q)) |_| break;
        if (try p.eatAnyNot(&.{ '%', '&', q })) |_| continue;
        if (try parsePEReference(alloc, p)) |_| continue;
        if (try parseReference(alloc, p)) |_| continue;
        unreachable;
    }
}

/// NDataDecl   ::=   S 'NDATA' S Name
fn parseNDataDecl(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    try parseS(p) orelse return null;
    try p.eat("NDATA") orelse return error.XmlMalformed;
    try parseS(p) orelse return error.XmlMalformed;
    return try parseName(alloc, p) orelse return error.XmlMalformed;
}

/// cp   ::=   (Name | choice | seq) ('?' | '*' | '+')?
fn parseCp(alloc: std.mem.Allocator, p: *Parser, sep_start: ?u8) anyerror!?void {
    _ = try parseName(alloc, p) orelse {
        _ = try parseChoiceOrSeq(alloc, p, false, sep_start) orelse {
            return null;
        };
    };
    _ = try p.eatAny(&.{ '?', '*', '+' }) orelse {};
}

/// NotationType   ::=   'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')'
fn parseNotationType(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringListIndex {
    var list = std.ArrayList(StringIndex).init(alloc);
    defer list.deinit();

    try p.eat("NOTATION") orelse return null;
    try parseS(p) orelse return error.XmlMalformed;
    try p.eat("(") orelse return error.XmlMalformed;
    try parseS(p) orelse {};
    try list.append(try parseName(alloc, p) orelse return error.XmlMalformed);
    while (true) {
        try parseS(p) orelse {};
        try p.eat("|") orelse break;
        try parseS(p) orelse {};
        try list.append(try parseName(alloc, p) orelse return error.XmlMalformed);
    }
    try parseS(p) orelse {};
    try p.eat(")") orelse return error.XmlMalformed;
    return try p.addStrList(alloc, list.items);
}

/// Enumeration   ::=   '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'
fn parseEnumeration(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringListIndex {
    var list = std.ArrayList(StringIndex).init(alloc);
    defer list.deinit();

    try p.eat("(") orelse return null;
    try parseS(p) orelse {};
    try list.append(try parseNmtoken(alloc, p) orelse return error.XmlMalformed);
    while (true) {
        try parseS(p) orelse {};
        _ = try p.eatByte('|') orelse break;
        try parseS(p) orelse {};
        try list.append(try parseNmtoken(alloc, p) orelse return error.XmlMalformed);
    }
    try parseS(p) orelse {};
    try p.eat(")") orelse return error.XmlMalformed;
    return try p.addStrList(alloc, list.items);
}

/// Nmtoken   ::=   (NameChar)+
fn parseNmtoken(alloc: std.mem.Allocator, p: *Parser) anyerror!?StringIndex {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    var i: usize = 0;
    while (true) : (i += 1) {
        if (try parseNameChar(p)) |c| {
            try addUCPtoList(&list, c);
            continue;
        }
        if (i == 0) return null;
        break;
    }
    return try p.addStr(alloc, list.items);
}

//
//

// Names   ::=   Name (#x20 Name)*
// Nmtokens   ::=   Nmtoken (#x20 Nmtoken)*
// extSubset   ::=   TextDecl? extSubsetDecl
// extSubsetDecl   ::=   ( markupdecl | conditionalSect | DeclSep)*
// SDDecl   ::=   S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"'))
// conditionalSect   ::=   includeSect | ignoreSect
// includeSect   ::=   '<![' S? 'INCLUDE' S? '[' extSubsetDecl ']]>'
// ignoreSect   ::=   '<![' S? 'IGNORE' S? '[' ignoreSectContents* ']]>'
// ignoreSectContents   ::=   Ignore ('<![' ignoreSectContents ']]>' Ignore)*
// Ignore   ::=   Char* - (Char* ('<![' | ']]>') Char*)
// TextDecl   ::=   '<?xml' VersionInfo? EncodingDecl S? '?>'
// extParsedEnt   ::=   TextDecl? content

//
//

fn addUCPtoList(list: *std.ArrayList(u8), cp: u21) !void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8CodepointSequenceLength(cp) catch unreachable;
    _ = std.unicode.utf8Encode(cp, buf[0..len]) catch unreachable;
    try list.appendSlice(buf[0..len]);
}

//
//

pub const StringIndex = enum(u32) {
    _,
};
pub const StringListIndex = enum(u32) {
    empty = std.math.maxInt(u32),
    _,
};

pub const Document = struct {
    allocator: std.mem.Allocator,
    extras: []const u32,
    string_bytes: []const u8,

    pub fn deinit(doc: *Document) void {
        doc.allocator.free(doc.extras);
        doc.allocator.free(doc.string_bytes);
        doc.* = undefined;
    }
};

pub const Standalone = enum {
    no,
    yes,
};

pub const Element = struct {
    tag_name: StringIndex,
};

pub const Reference = union(enum) {
    char: u21,
    entity: void,
};

pub const PI = struct {
    target: StringIndex,
    rest: StringIndex,
};

pub const TokenizedType = enum {
    IDREFS,
    IDREF,
    ID,
    ENTITY,
    ENTITIES,
    NMTOKENS,
    NMTOKEN,
};

pub const EnumeratedType = union(enum) {
    notation_type: StringListIndex,
    enumeration: StringListIndex,
};

pub const AttType = union(enum) {
    string: void,
    tokenized: TokenizedType,
    enumerated: EnumeratedType,
};

pub const XMLDecl = struct {
    encoding: ?StringIndex,
    standalone: ?Standalone,
};

pub const ID = union(enum) {
    public: StringIndex,
    external: ExternalID,
};

pub const ExternalID = union(enum) {
    system: StringIndex,
    public: [2]StringIndex,
};
