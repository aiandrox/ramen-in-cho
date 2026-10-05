import ImageIO
import UIKit
import UniformTypeIdentifiers

/// ほかのアプリの「共有」から写真を受け取り、本体と共有する場所（App Group）に預けて麺印帳を開く。
/// 本体は開いたときに預かった写真を受け取り、記録画面を開く。
class ShareViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let provider = imageProvider() else {
      finish()
      return
    }
    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) {
      [weak self] url, _ in
      // 渡された一時ファイルはこの中でしか読めないので、すぐに写す。
      if let url { SharedPhotoInbox.put(from: url) }
      DispatchQueue.main.async {
        self?.openApp()
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

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }

  // 拡張機能からは UIApplication を直接使えないので、つながっている画面をたどって開く。
  private func openApp() {
    guard let url = URL(string: "ramenincho://shared-photo") else { return }
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
