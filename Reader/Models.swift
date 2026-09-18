import UIKit

struct Chapter: Codable, Equatable {
    var title: String
    var text: String
    var images: [InlineImage] = []
}
struct InlineImage: Codable, Equatable {
    var utf16Offset: Int
    var relativePath: String
}
struct ReadingAnchor: Codable, Equatable {
    var chapter: Int = 0
    var utf16Offset: Int = 0
}
struct Bookmark: Codable, Identifiable {
    var id = UUID()
    var anchor: ReadingAnchor
    var excerpt: String
}
struct LocalBook: Codable, Identifiable {
    var id: String // SHA-256 of the source, used for duplicate detection
    var title: String
    var chapters: [Chapter]
    var progress = ReadingAnchor()
    var bookmarks: [Bookmark] = []
    var importedAt = Date()
}
enum PageTurnMode: String, Codable, CaseIterable {
    case cover, slide, curl, vertical, instant
    var title: String {
        switch self {
        case .cover: return "覆盖"
        case .slide: return "平移"
        case .curl: return "仿真（待对照）"
        case .vertical: return "上下"
        case .instant: return "无动画"
        }
    }
}
enum ReaderTheme: String, Codable, CaseIterable {
    case paper, white, green, dark
    var background: UIColor {
        switch self {
        case .paper: return UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1)
        case .white: return .white
        case .green: return UIColor(red: 0.82, green: 0.89, blue: 0.81, alpha: 1)
        case .dark: return UIColor(white: 0.10, alpha: 1)
        }
    }
    var foreground: UIColor { self == .dark ? UIColor(white: 0.72, alpha: 1) : UIColor(white: 0.16, alpha: 1) }
}
struct ReaderSettings: Codable {
    var fontSize: Double = 22
    var lineSpacing: Double = 8
    var paragraphSpacing: Double = 12
    var horizontalMargin: Double = 24
    var theme: ReaderTheme = .paper
    var turnMode: PageTurnMode = .cover
    var fontName: String? = nil
    // Product defaults above are provisional, not claimed APK defaults.
    mutating func normalize() {
        fontSize = min(40, max(14, fontSize.isFinite ? fontSize : 22))
        lineSpacing = min(24, max(0, lineSpacing.isFinite ? lineSpacing : 8))
        paragraphSpacing = min(32, max(0, paragraphSpacing.isFinite ? paragraphSpacing : 12))
        horizontalMargin = min(48, max(12, horizontalMargin.isFinite ? horizontalMargin : 24))
    }
}
enum ReaderError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

@MainActor final class LibraryStore {
    let root: URL
    private(set) var books: [LocalBook] = []
    var settings = ReaderSettings()
    private(set) var loadError: Error?
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LocalReader", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let index = self.root.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: index.path) {
                books = try JSONDecoder().decode([LocalBook].self, from: Data(contentsOf: index))
            }
            let prefs = self.root.appendingPathComponent("settings.json")
            if FileManager.default.fileExists(atPath: prefs.path) {
                settings = try JSONDecoder().decode(ReaderSettings.self, from: Data(contentsOf: prefs))
                settings.normalize()
            }
        } catch { loadError = error } // Never overwrite an unreadable library silently.
    }
    func persist() throws {
        guard loadError == nil else { throw ReaderError.invalid("书架读取失败，已停止写入以保护原数据。") }
        try JSONEncoder().encode(books).write(to: root.appendingPathComponent("library.json"), options: .atomic)
        try JSONEncoder().encode(settings).write(to: root.appendingPathComponent("settings.json"), options: .atomic)
    }
    func insert(_ book: LocalBook) throws {
        guard !books.contains(where: { $0.id == book.id }) else { throw ReaderError.invalid("这本书已经在书架中。") }
        books.insert(book, at: 0)
        do { try persist() } catch { books.removeAll { $0.id == book.id }; throw error }
    }
    func update(_ book: LocalBook) throws {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let old = books[index]; books[index] = book
        do { try persist() } catch { books[index] = old; throw error }
    }
    func delete(_ id: String) throws {
        let old = books; books.removeAll { $0.id == id }
        do { try persist() } catch { books = old; throw error }
        let folder = root.appendingPathComponent(id)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }
}
