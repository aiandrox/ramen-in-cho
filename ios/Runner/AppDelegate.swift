import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // アプリを開いている間も、並んでいる間の通知を出せるようにする（flutter_local_notifications）。
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SharedPhoto") {
      SharedPhoto.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SystemSettings") {
      SystemSettings.register(with: registrar.messenger())
    }
  }
}

/// 共有の拡張機能（ShareExtension）が App Group に預けた写真を受け取る。
enum SharedPhoto {
  private static let appGroup = "group.com.aiandrox.ramenInCho"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.aiandrox.ramen_in_cho/shared_photo", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "takeSharedPhoto" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(take())
    }
  }

  /// 預かった写真をアプリの一時フォルダへ移し、そのパスを返す。無ければnil。
  private static func take() -> String? {
    let files = FileManager.default
    guard
      let container = files.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    else { return nil }
    let directory = container.appendingPathComponent("shared_photos", isDirectory: true)
    guard
      let photo = try? files.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
      ).first
    else { return nil }
    let destination = files.temporaryDirectory.appendingPathComponent(photo.lastPathComponent)
    try? files.removeItem(at: destination)
    do {
      try files.moveItem(at: photo, to: destination)
      return destination.path
    } catch {
      try? files.removeItem(at: photo)
      return nil
    }
  }
}

/// スマホの設定のうち、麺印帳の通知の画面を開く。
enum SystemSettings {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.aiandrox.ramen_in_cho/system_settings", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let name: String
      if #available(iOS 16.0, *) {
        name = UIApplication.openNotificationSettingsURLString
      } else {
        name = UIApplication.openSettingsURLString
      }
      if let url = URL(string: name) {
        UIApplication.shared.open(url)
      }
      result(nil)
    }
  }
}
