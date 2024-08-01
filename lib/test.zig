const std = @import("std");
const xml = @import("xml");

const expect = std.testing.expect;
const string = []const u8;

// zig fmt: off
test "sa-001" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/001.xml"); }
test "sa-002" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/002.xml"); }
test "sa-003" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/003.xml"); }
test "sa-004" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/004.xml"); }
test "sa-005" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/005.xml"); }
test "sa-006" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/006.xml"); }
test "sa-007" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/007.xml"); }
test "sa-008" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/008.xml"); }
test "sa-009" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/009.xml"); }
test "sa-010" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/010.xml"); }
test "sa-011" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/011.xml"); }
test "sa-012" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/012.xml"); }
test "sa-013" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/013.xml"); }
test "sa-014" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/014.xml"); }
test "sa-015" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/015.xml"); }
test "sa-016" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/016.xml"); }
test "sa-017" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/017.xml"); }
test "sa-018" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/018.xml"); }
test "sa-019" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/019.xml"); }
test "sa-020" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/020.xml"); }
test "sa-021" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/021.xml"); }
test "sa-022" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/022.xml"); }
test "sa-023" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/023.xml"); }
test "sa-024" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/024.xml"); }
test "sa-025" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/025.xml"); }
test "sa-026" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/026.xml"); }
test "sa-027" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/027.xml"); }
test "sa-028" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/028.xml"); }
test "sa-029" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/029.xml"); }
test "sa-030" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/030.xml"); }
test "sa-031" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/031.xml"); }
test "sa-032" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/032.xml"); }
test "sa-033" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/033.xml"); }
test "sa-034" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/034.xml"); }
test "sa-035" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/035.xml"); }
test "sa-036" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/036.xml"); }
test "sa-037" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/037.xml"); }
test "sa-038" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/038.xml"); }
test "sa-039" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/039.xml"); }
test "sa-040" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/040.xml"); }
test "sa-041" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/041.xml"); }
test "sa-042" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/042.xml"); }
test "sa-043" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/043.xml"); }
test "sa-044" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/044.xml"); }
test "sa-045" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/045.xml"); }
test "sa-046" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/046.xml"); }
test "sa-047" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/047.xml"); }
test "sa-048" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/048.xml"); }
test "sa-049" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/049.xml"); }
test "sa-050" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/050.xml"); }
test "sa-051" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/051.xml"); }
test "sa-052" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/052.xml"); }
test "sa-053" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/053.xml"); }
test "sa-054" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/054.xml"); }
test "sa-055" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/055.xml"); }
test "sa-056" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/056.xml"); }
test "sa-057" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/057.xml"); }
test "sa-058" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/058.xml"); }
test "sa-059" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/059.xml"); }
test "sa-060" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/060.xml"); }
test "sa-061" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/061.xml"); }
test "sa-062" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/062.xml"); }
test "sa-063" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/063.xml"); }
test "sa-064" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/064.xml"); }
test "sa-065" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/065.xml"); }
test "sa-066" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/066.xml"); }
test "sa-067" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/067.xml"); }
test "sa-068" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/068.xml"); }
test "sa-069" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/069.xml"); }
test "sa-070" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/070.xml"); }
test "sa-071" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/071.xml"); }
test "sa-072" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/072.xml"); }
test "sa-073" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/073.xml"); }
test "sa-074" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/074.xml"); }
test "sa-075" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/075.xml"); }
test "sa-076" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/076.xml"); }
test "sa-077" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/077.xml"); }
test "sa-078" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/078.xml"); }
test "sa-079" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/079.xml"); }
test "sa-080" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/080.xml"); }
test "sa-081" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/081.xml"); }
test "sa-082" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/082.xml"); }
test "sa-083" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/083.xml"); }
test "sa-084" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/084.xml"); }
test "sa-085" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/085.xml"); }
test "sa-086" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/086.xml"); }
test "sa-087" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/087.xml"); }
test "sa-088" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/088.xml"); }
test "sa-089" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/089.xml"); }
test "sa-090" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/090.xml"); }
test "sa-091" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/091.xml"); }
test "sa-092" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/092.xml"); }
test "sa-093" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/093.xml"); }
test "sa-094" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/094.xml"); }
test "sa-095" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/095.xml"); }
test "sa-096" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/096.xml"); }
test "sa-097" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/097.xml"); }
test "sa-098" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/098.xml"); }
test "sa-099" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/099.xml"); }
test "sa-100" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/100.xml"); }
test "sa-101" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/101.xml"); }
test "sa-102" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/102.xml"); }
test "sa-103" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/103.xml"); }
test "sa-104" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/104.xml"); }
test "sa-105" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/105.xml"); }
test "sa-106" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/106.xml"); }
test "sa-107" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/107.xml"); }
test "sa-108" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/108.xml"); }
test "sa-109" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/109.xml"); }
test "sa-110" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/110.xml"); }
test "sa-111" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/111.xml"); }
test "sa-112" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/112.xml"); }
test "sa-113" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/113.xml"); }
test "sa-114" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/114.xml"); }
test "sa-115" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/115.xml"); }
test "sa-116" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/116.xml"); }
test "sa-117" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/117.xml"); }
test "sa-118" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/118.xml"); }
test "sa-119" { try doValid("xml-test-suite/xmlconf/xmltest/valid/sa/119.xml"); }
// zig fmt: on

fn doValid(testfile_path: string) !void {
    var testfile_file = try std.fs.cwd().openFile(testfile_path, .{});
    defer testfile_file.close();
    var doc = try xml.parse(std.testing.allocator, testfile_path, testfile_file.reader());
    defer doc.deinit();
}

test "books" {
    const input =
        \\<?xml version="1.0" standalone="yes" ?>
        \\<category name="Technology">
        \\  <book title="Learning Amazon Web Services" author="Mark Wilkins">
        \\    <price>$20</price>
        \\  </book>
        \\  <book title="The Hunger Games" author="Suzanne Collins">
        \\    <price>$13</price>
        \\  </book>
        \\  <book title="The Lightning Thief: Percy Jackson and the Olympians" author="Rick Riordan"></book>
        \\</category>
    ;
    var fbs = std.io.fixedBufferStream(input);
    var doc = try xml.parse(std.testing.allocator, "<stdin>", fbs.reader());
    defer doc.deinit();
    doc.acquire();
    defer doc.release();

    try expectEqualStrings(doc.root.tag_name.slice(), "category");

    const children = doc.root.children();
    try expect(children.len == 3);
    try expect(children[0].v() == .element);
    try expect(children[1].v() == .element);
    try expect(children[2].v() == .element);

    const child1 = children[1].v().element;
    try expectEqualStrings(child1.tag_name.slice(), "book");
    try expectEqualStrings(child1.attr("title").?, "The Hunger Games");

    const children2 = child1.children();
    try expect(children2.len == 1);
    try expect(children2[0].v() == .element);

    const child2 = children2[0].v().element;
    try expectEqualStrings(child2.tag_name.slice(), "price");
    const children3 = child2.children();
    try expect(children3.len == 1);
    try expect(children3[0].v() == .text);
    try expectEqualStrings(children3[0].v().text.slice(), "$13");
}

fn expectEqualStrings(actual: []const u8, expected: []const u8) !void {
    try std.testing.expectEqualStrings(expected, actual);
}
