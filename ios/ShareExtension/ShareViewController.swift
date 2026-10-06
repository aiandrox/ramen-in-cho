import ImageIO
import UIKit
import UniformTypeIdentifiers

/// ほかのアプリの「共有」から写真や文（店・動画のリンクなど）を受け取り、本体と共有する場所（App Group）に預けて麺印帳を開く。
/// 本体は開いたときに預かった写真なら記録画面を、文なら願を掛ける窓を開く。
class ShareViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let provider = imageProvider() else {
      receiveText()
      return
    }
    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) {
      [weak self] url, _ in
      // 渡された一時ファイルはこの中でしか読めないので、すぐに写す。
      if let url { SharedPhotoInbox.put(from: url) }
      DispatchQueue.main.async {
        self?.openApp(path: "shared-photo")
        self?.finish()
      }
    }
  }

  private func imageProvider() -> NSItemProvider? {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    return items.lazy
      .flatMap { $0.attachments ?? [] }
      .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
  }

  /// 写真でなければ、Google マップの店や YouTube の動画など、共有された文とリンクを預ける。
  private func receiveText() {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    var pieces = items.compactMap { $0.attributedContentText?.string }
    let subject = items.compactMap { $0.attributedTitle?.string }.first
    let group = DispatchGroup()
    let lock = NSLock()
    for provider in providers {
      for type in [UTType.url, UTType.plainText]
      where provider.hasItemConformingToTypeIdentifier(type.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: type.identifier) { item, _ in
          let text: String? =
            switch item {
            case let url as URL: url.isFileURL ? nil : url.absoluteString
            case let string as String: string
            case let data as Data: String(data: data, encoding: .utf8)
            default: nil
            }
          if let text {
            lock.lock()
            pieces.append(text)
            lock.unlock()
          }
          group.leave()
        }
        break
      }
    }
    group.notify(queue: .main) { [weak self] in
      if SharedTextInbox.put(pieces: pieces, subject: subject) {
        self?.openApp(path: "shared-text")
      }
      self?.finish()
    }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }

  // 拡張機能からは UIApplication を直接使えないので、つながっている画面をたどって開く。
  private func openApp(path: String) {
    guard let url = URL(string: "ramenincho://\(path)") else { return }
    var responder: UIResponder? = self
    while let current = responder {
      if let application = current as? UIApplication {
        application.open(url, options: [:], completionHandler: nil)
        return
      }
      responder = current.next
    }
  }
}

enum SharedTextInbox {
  private static let maxLength = 2000

  /// 同じ文（リンクが本文にも入っているなど）は1つにまとめ、App Group の shared_text.json に預ける。預けられれば true。
  static func put(pieces: [String], subject: String?) -> Bool {
    var lines: [String] = []
    for piece in pieces {
      let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty || lines.contains(where: { $0.contains(trimmed) }) { continue }
      lines.removeAll { trimmed.contains($0) }
      lines.append(trimmed)
    }
    let text = String(lines.joined(separator: "\n").prefix(maxLength))
    guard !text.isEmpty,
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: SharedPhotoInbox.appGroup)
    else { return false }
    var body: [String: String] = ["text": text]
    if let subject, !subject.isEmpty { body["subject"] = String(subject.prefix(maxLength)) }
    guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
    do {
      try data.write(
        to: container.appendingPathComponent("shared_text.json"), options: .atomic)
      return true
    } catch {
      return false
    }
  }
}

enum SharedPhotoInbox {
  static let appGroup = "group.com.aiandrox.ramenInCho"
  private static let maxSize = 2000
  private static let quality = 0.85

  /// ギャラリーから選んだときと同じ大きさに縮め、撮影日時と撮影場所は残す。
  static func put(from source: URL) {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup)
    else { return }
    let directory = container.appendingPathComponent("shared_photos", isDirectory: true)
    try? FileManager.default.removeItem(at: directory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = directory.appendingPathComponent(
      "shared-\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
    if !resize(source, to: destination) {
      try? FileManager.default.copyItem(at: source, to: destination)
    }
  }

  private static func resize(_ source: URL, to destination: URL) -> Bool {
    guard let image = CGImageSourceCreateWithURL(source as CFURL, nil),
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        image, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxSize,
        ] as CFDictionary),
      let output = CGImageDestinationCreateWithURL(
        destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { return false }
    var properties =
      CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any] ?? [:]
    // 縮めるときに向きを直したので、向きの情報は「そのまま」にする。
    properties[kCGImagePropertyOrientation] = 1
    if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
      tiff[kCGImagePropertyTIFFOrientation] = 1
      properties[kCGImagePropertyTIFFDictionary] = tiff
    }
    properties.removeValue(forKey: kCGImagePropertyPixelWidth)
    properties.removeValue(forKey: kCGImagePropertyPixelHeight)
    properties[kCGImageDestinationLossyCompressionQuality] = quality
    CGImageDestinationAddImage(output, thumbnail, properties as CFDictionary)
    return CGImageDestinationFinalize(output)
  }
}
