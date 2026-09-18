import UIKit
import UniformTypeIdentifiers
import CryptoKit

// Buildable development baseline, NOT the completed reverse-engineered renderer.
@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: ShelfController())
        window.makeKeyAndVisible(); self.window = window
        return true
    }
}

@MainActor final class ShelfController: UITableViewController, UIDocumentPickerDelegate {
    private let store = LibraryStore()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "本地书架 · 开发版"
        tableView.accessibilityIdentifier = "shelf"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "导入 TXT", style: .plain, target: self, action: #selector(importBook))
        let note = UILabel(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        note.text = "云端构建基线\n尚未完成番茄排版、翻页及 EPUB 接入"
        note.numberOfLines = 0; note.textAlignment = .center; note.textColor = .secondaryLabel
        tableView.tableHeaderView = note
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let error = store.loadError { show(error) }
    }
    @objc private func importBook() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: true)
        picker.delegate = self; present(picker, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? Int.max) <= 8 * 1024 * 1024 else { throw ReaderError.invalid("开发版暂限 8 MB 以内的 TXT。") }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16), !text.isEmpty else {
                throw ReaderError.invalid("开发版仅接收非空 UTF-8 / UTF-16 文本。")
            }
            let id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let title = url.deletingPathExtension().lastPathComponent
            try store.insert(LocalBook(id: id, title: title, chapters: [Chapter(title: title, text: text)]))
            tableView.reloadData()
        } catch { show(error) }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { store.books.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = store.books[indexPath.row].title
        cell.detailTextLabel?.text = "仅本地保存 · 临时文本视图"; cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let book = store.books[indexPath.row]
        let reader = UIViewController(); reader.title = book.title
        let text = UITextView(); text.isEditable = false
        text.font = .systemFont(ofSize: 22); text.text = book.chapters.map(\.text).joined(separator: "\n\n")
        text.backgroundColor = store.settings.theme.background; text.textColor = store.settings.theme.foreground
        text.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        reader.view = text; navigationController?.pushViewController(reader, animated: true)
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        do { try store.delete(store.books[indexPath.row].id); tableView.reloadData() } catch { show(error) }
    }
    private func show(_ error: Error) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "提示", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default)); present(alert, animated: true)
    }
}
