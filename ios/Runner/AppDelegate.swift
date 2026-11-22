import Flutter
import UIKit
import PDFKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  UIDocumentPickerDelegate {
  private var pendingPick: FlutterResult?
  private let maxSize = 5 * 1024 * 1024

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "edu.parsu.motopass/documents",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "renderPdf" {
        self?.renderPdf(call.arguments, result)
        return
      }
      guard call.method == "pick" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.pickDocument(result)
    }
  }

  private func renderPdf(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
      let bytes = args["bytes"] as? FlutterStandardTypedData,
      bytes.data.count <= maxSize, let index = args["page"] as? Int,
      let pdf = PDFDocument(data: bytes.data), let page = pdf.page(at: index),
      let image = page.thumbnail(of: CGSize(width: 1200, height: 1200), for: .cropBox).pngData()
    else {
      result(FlutterError(code: "pdf", message: "Could not display the PDF.", details: nil))
      return
    }
    result(["count": pdf.pageCount, "image": FlutterStandardTypedData(bytes: image)])
  }

  private func pickDocument(_ result: @escaping FlutterResult) {
    guard pendingPick == nil else {
      result(FlutterError(code: "busy", message: "A document picker is already open.", details: nil))
      return
    }
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    guard let controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      result(FlutterError(code: "unavailable", message: "No document picker is available.", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .png, .jpeg], asCopy: true)
    picker.delegate = self
    pendingPick = result
    controller.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPick(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      finishPick(nil)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let result: Any
      do {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var bytes = Data()
        while bytes.count <= self.maxSize,
          let chunk = try handle.read(upToCount: min(65536, self.maxSize + 1 - bytes.count)),
          !chunk.isEmpty {
          bytes.append(chunk)
        }
        if bytes.isEmpty || bytes.count > self.maxSize {
          result = FlutterError(code: "size", message: "Choose a file between 1 byte and 5 MB.", details: nil)
        } else {
          result = ["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: bytes)]
        }
      } catch {
        result = FlutterError(code: "read_failed", message: "Could not read the selected file.", details: nil)
      }
      // The picker supplies a temporary copy for this selection.
      try? FileManager.default.removeItem(at: url)
      DispatchQueue.main.async { self.finishPick(result) }
    }
  }

  private func finishPick(_ value: Any?) {
    let reply = pendingPick
    pendingPick = nil
    reply?(value)
  }
}
