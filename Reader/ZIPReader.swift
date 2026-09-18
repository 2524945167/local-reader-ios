import Foundation

// Local-only ZIP reader. No extraction to caller-controlled paths; no ZIP64, encryption or symlinks.
struct ZIPReader {
    struct Entry { let name: String; let method: Int; let crc: UInt32; let compressed: Int; let size: Int; let offset: Int }
    let data: Data
    private(set) var entries: [String: Entry] = [:]
    init(_ data: Data) throws {
        guard data.count >= 22, data.count <= 128 * 1024 * 1024 else { throw ReaderError.invalid("EPUB 大小不合法（上限 128 MB）。") }
        self.data = data
        var end: Int?
        for i in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            if try data.le32(i) == 0x06054b50, i + 22 + Int(try data.le16(i + 20)) == data.count { end = i; break }
        }
        guard let end else { throw ReaderError.invalid("缺少 ZIP 目录。") }
        let count = Int(try data.le16(end + 10))
        guard try data.le16(end + 4) == 0, try data.le16(end + 6) == 0,
              try data.le16(end + 8) == UInt16(count), count < 10000,
              count != 65535 else { throw ReaderError.invalid("不支持分卷或 ZIP64 EPUB。") }
        var cursor = Int(try data.le32(end + 16)); let centralEnd = cursor + Int(try data.le32(end + 12))
        guard centralEnd <= end else { throw ReaderError.invalid("ZIP 目录越界。") }
        var total = 0
        for _ in 0..<count {
            guard try data.le32(cursor) == 0x02014b50 else { throw ReaderError.invalid("ZIP 目录损坏。") }
            let flags = try data.le16(cursor + 8)
            let method = Int(try data.le16(cursor + 10))
            let packed = Int(try data.le32(cursor + 20)); let size = Int(try data.le32(cursor + 24))
            let nameLength = Int(try data.le16(cursor + 28)); let extra = Int(try data.le16(cursor + 30)); let comment = Int(try data.le16(cursor + 32))
            let nameData = try data.checked(cursor + 46, nameLength)
            guard let name = String(data: nameData, encoding: .utf8), Self.safePath(name), flags & 1 == 0,
                  method == 0 || method == 8, size <= 32 * 1024 * 1024,
                  ((try data.le32(cursor + 38)) >> 16) & 0xf000 != 0xa000 else {
                throw ReaderError.invalid("EPUB 含加密、不支持的压缩方式或不安全路径。")
            }
            total += size
            guard total <= 256 * 1024 * 1024, entries[name] == nil else { throw ReaderError.invalid("EPUB 解压内容过大或文件名重复。") }
            entries[name] = Entry(name: name, method: method, crc: try data.le32(cursor + 16), compressed: packed, size: size, offset: Int(try data.le32(cursor + 42)))
            cursor += 46 + nameLength + extra + comment
            guard cursor <= centralEnd else { throw ReaderError.invalid("ZIP 目录长度错误。") }
        }
        guard cursor == centralEnd else { throw ReaderError.invalid("ZIP 目录大小不匹配。") }
    }
    static func safePath(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix("/") && !name.contains("\\") && !name.contains(":") && !name.contains("\0") && !name.split(separator: "/").contains("..")
    }
    func read(_ name: String) throws -> Data {
        guard let entry = entries[name] else { throw ReaderError.invalid("EPUB 缺少文件：\(name)") }
        let o = entry.offset
        guard try data.le32(o) == 0x04034b50, try data.le16(o + 6) & 1 == 0,
              Int(try data.le16(o + 8)) == entry.method else { throw ReaderError.invalid("ZIP 本地文件头错误。") }
        let nameLength = Int(try data.le16(o + 26))
        guard String(data: try data.checked(o + 30, nameLength), encoding: .utf8) == name else { throw ReaderError.invalid("ZIP 文件名不匹配。") }
        let start = o + 30 + nameLength + Int(try data.le16(o + 28))
        let packed = try data.checked(start, entry.compressed)
        var result: Data
        if entry.method == 0 {
            guard entry.size == packed.count else { throw ReaderError.invalid("ZIP 长度不匹配。") }
            result = packed
        } else {
            result = Data(count: max(1, entry.size))
            let status = result.withUnsafeMutableBytes { dst in packed.withUnsafeBytes { src in
                reader_inflate(src.bindMemory(to: UInt8.self).baseAddress, packed.count, dst.bindMemory(to: UInt8.self).baseAddress, entry.size)
            } }
            guard status == 0 else { throw ReaderError.invalid("EPUB 解压失败。") }
            result.count = entry.size
        }
        let crc = result.withUnsafeBytes { reader_crc32($0.bindMemory(to: UInt8.self).baseAddress, result.count) }
        guard crc == entry.crc else { throw ReaderError.invalid("EPUB 文件 CRC 校验失败。") }
        return result
    }
}
extension Data {
    func checked(_ offset: Int, _ count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset <= self.count, count <= self.count - offset else { throw ReaderError.invalid("文件数据越界。") }
        return subdata(in: offset..<(offset + count))
    }
    func le16(_ o: Int) throws -> UInt16 { let b = try checked(o, 2); return UInt16(b[0]) | (UInt16(b[1]) << 8) }
    func le32(_ o: Int) throws -> UInt32 { let b = try checked(o, 4); return UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24) }
}
