import XCTest
@testable import LocalReader

final class ReaderTests: XCTestCase {
    func testSettingsClampInvalidValues() {
        var settings = ReaderSettings(); settings.fontSize = .nan; settings.horizontalMargin = 1000
        settings.normalize()
        XCTAssertEqual(settings.fontSize, 22); XCTAssertEqual(settings.horizontalMargin, 48)
    }
    func testAnchorPreservesUTF16Position() throws {
        let anchor = ReadingAnchor(chapter: 3, utf16Offset: 42)
        XCTAssertEqual(try JSONDecoder().decode(ReadingAnchor.self, from: JSONEncoder().encode(anchor)), anchor)
    }
    func testZIPRejectsInvalidDataAndPaths() {
        XCTAssertThrowsError(try ZIPReader(Data(repeating: 0, count: 30)))
        for path in ["../bad", "/absolute", "C:/bad", "a/../b", "a\\b"] { XCTAssertFalse(ZIPReader.safePath(path)) }
        XCTAssertTrue(ZIPReader.safePath("OPS/chapter.xhtml"))
    }
    func testStoredZIPRoundTripAndCRC() throws {
        let body = Data("hello".utf8); let name = Data("test.txt".utf8)
        let crc = body.withUnsafeBytes { reader_crc32($0.bindMemory(to: UInt8.self).baseAddress, body.count) }
        func u16(_ value: UInt16) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
        func u32(_ value: UInt32) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
        var local = u32(0x04034b50)
        for value in [20, 0, 0, 0, 0] as [UInt16] { local += u16(value) }
        local += u32(crc); local += u32(5); local += u32(5); local += u16(8); local += u16(0)
        local += name; local += body
        var central = u32(0x02014b50)
        for value in [20, 20, 0, 0, 0, 0] as [UInt16] { central += u16(value) }
        central += u32(crc); central += u32(5); central += u32(5)
        for value in [8, 0, 0, 0, 0] as [UInt16] { central += u16(value) }
        central += u32(0); central += u32(0); central += name
        var end = u32(0x06054b50)
        for value in [0, 0, 1, 1] as [UInt16] { end += u16(value) }
        end += u32(UInt32(central.count)); end += u32(UInt32(local.count)); end += u16(0)
        let archive = local + central + end
        XCTAssertEqual(try ZIPReader(archive).read("test.txt"), body)
        var corrupt = archive; corrupt[38] ^= 1
        XCTAssertThrowsError(try ZIPReader(corrupt).read("test.txt"))
    }
    @MainActor func testLibraryPersistenceAndDuplicate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root)
        let book = LocalBook(id: "fixture", title: "测试", chapters: [Chapter(title: "第一章", text: "正文😀")])
        try store.insert(book); XCTAssertThrowsError(try store.insert(book))
        XCTAssertEqual(LibraryStore(root: root).books.first?.title, "测试")
        try store.delete(book.id); XCTAssertTrue(LibraryStore(root: root).books.isEmpty)
    }
}
