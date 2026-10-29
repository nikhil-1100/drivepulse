import CryptoKit
import Flutter
import UIKit
import UniformTypeIdentifiers

/// DrivePulse native storage bridge (iOS).
///
/// iOS does not expose raw USB block devices to third-party apps. DrivePulse
/// therefore manages two kinds of roots: the app's own Documents folder (which
/// appears in Files) and any folders the user authorises through the system
/// document picker, persisted as security-scoped bookmarks. Everything else —
/// hashing, copy, benchmark, encryption I/O — is local.
final class StorageBridge: NSObject, FlutterPlugin, FlutterStreamHandler,
    UIDocumentPickerDelegate {

  private struct BookmarkRecord {
    let label: String
    let data: Data
  }

  private static let bookmarksKey = "drivepulse.bookmarks.v1"
  private static let maxReadBytes: Int64 = 128 * 1024 * 1024
  private static let bufferSize = 256 * 1024

  private var channel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?
  private var bookmarks: [BookmarkRecord] = []
  private var scopedRoots: [String: URL] = [:]
  private var transferState: [String: String] = [:]
  private var pendingFolder: FlutterResult?
  private var pendingFiles: FlutterResult?

  private let fileManager = FileManager.default
  private let ioQueue = DispatchQueue(label: "com.drivepulse.storage", qos: .userInitiated)
  private let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  init(registrar: FlutterPluginRegistrar) {
    super.init()
    loadBookmarks()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = StorageBridge(registrar: registrar)
    let channel = FlutterMethodChannel(
      name: "drivepulse/storage",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.channel = channel

    let events = FlutterEventChannel(
      name: "drivepulse/volumes",
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
  }

  // MARK: - Method channel

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "listVolumes":
        result(volumes())
      case "refreshVolume":
        let args = call.arguments as? [String: Any]
        let id = args?["volumeId"] as? String
        result(volumes().first { ($0["id"] as? String) == id })
      case "listDirectory":
        result(try listDirectory(path(call)))
      case "stat":
        result(stat(path(call)))
      case "summarize":
        let args = call.arguments as? [String: Any]
        result(try summarize(
          path(call),
          maxDepth: args?["maxDepth"] as? Int ?? 8,
          maxEntries: args?["maxEntries"] as? Int ?? 40000
        ))
      case "search":
        let args = call.arguments as? [String: Any]
        result(try search(
          path(call),
          query: args?["query"] as? String ?? "",
          limit: args?["limit"] as? Int ?? 300
        ))
      case "createFolder":
        let args = call.arguments as? [String: Any]
        try createFolder(
          parent: args?["parent"] as? String ?? "",
          name: args?["name"] as? String ?? ""
        )
        result(nil)
      case "rename":
        let args = call.arguments as? [String: Any]
        try rename(path(call), newName: args?["newName"] as? String ?? "")
        result(nil)
      case "delete":
        let args = call.arguments as? [String: Any]
        let entries = args?["entries"] as? [[String: Any]] ?? []
        for entry in entries {
          if let entryPath = entry["path"] as? String {
            try delete(entryPath)
          }
        }
        result(nil)
      case "transfer":
        startTransfer(call, result: result)
      case "pauseTransfer":
        let args = call.arguments as? [String: Any]
        if let taskId = args?["taskId"] as? String {
          transferState[taskId] = (args?["paused"] as? Bool ?? false) ? "paused" : "running"
        }
        result(nil)
      case "cancelTransfer":
        let args = call.arguments as? [String: Any]
        if let taskId = args?["taskId"] as? String {
          transferState[taskId] = "cancelled"
        }
        result(nil)
      case "benchmark":
        startBenchmark(call, result: result)
      case "eject":
        let args = call.arguments as? [String: Any]
        if let id = args?["volumeId"] as? String {
          scopedRoots[id]?.stopAccessingSecurityScopedResource()
        }
        result(true)
      case "readFile":
        result(try readBytes(path(call)))
      case "writeFile":
        let args = call.arguments as? [String: Any]
        let data = args?["bytes"] as? FlutterStandardTypedData
        try writeBytes(path(call), data: data?.data ?? Data())
        result(nil)
      case "hashFile":
        result(try hashFile(path(call)))
      case "exists":
        result(fileManager.fileExists(atPath: path(call)))
      case "pickDirectory":
        pickDirectory(result: result)
      case "pickFiles":
        let args = call.arguments as? [String: Any]
        pickFiles(result: result, multiple: args?["multiple"] as? Bool ?? true)
      case "deviceInfo":
        result(deviceInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let error as StorageError {
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      result(FlutterError(
        code: "io",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  // MARK: - Volumes

  private func volumes() -> [[String: Any]] {
    var result: [[String: Any]] = []
    let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    result.append(volumeJSON(
      id: "ios-documents",
      label: "On My iPhone",
      kind: "internal",
      mount: documents.path,
      protocolLabel: "App container"
    ))

    for (index, bookmark) in bookmarks.enumerated() {
      var stale = false
      guard let url = try? URL(
        resolvingBookmarkData: bookmark.data,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      ) else {
        continue
      }
      _ = url.startAccessingSecurityScopedResource()
      scopedRoots["bm:\(index)"] = url
      result.append(volumeJSON(
        id: "bm:\(index)",
        label: bookmark.label,
        kind: "externalSsd",
        mount: url.path,
        protocolLabel: "Authorised folder"
      ))
    }
    return result
  }

  private func volumeJSON(
    id: String,
    label: String,
    kind: String,
    mount: String,
    protocolLabel: String
  ) -> [String: Any] {
    let url = URL(fileURLWithPath: mount)
    let values = try? url.resourceValues(forKeys: [
      .volumeTotalCapacityKey,
      .volumeAvailableCapacityKey,
      .volumeIsReadOnlyKey,
    ])
    let total = Int64(values?.volumeTotalCapacity ?? 0)
    let free = Int64(values?.volumeAvailableCapacity ?? 0)
    return [
      "id": id,
      "label": label,
      "fileSystem": "APFS",
      "totalBytes": total,
      "freeBytes": free,
      "kind": kind,
      "busLabel": "Local",
      "protocolLabel": protocolLabel,
      "serial": "",
      "mountPath": mount,
      "readMbps": 0.0,
      "writeMbps": 0.0,
      "healthPercent": total > 0 ? 100 : 0,
      "isReadOnly": values?.volumeIsReadOnly ?? false,
      "isConnected": true,
      "smartSupported": false,
      "lastSeen": isoFormatter.string(from: Date()),
    ]
  }

  // MARK: - Listing

  private func listDirectory(_ path: String) throws -> [[String: Any]] {
    let url = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw StorageError(code: "not_found", message: "Folder not found")
    }
    let contents = try fileManager.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
      ],
      options: []
    )
    return contents.map { entryJSON($0) }
  }

  private func entryJSON(_ url: URL) -> [String: Any] {
    let values = try? url.resourceValues(forKeys: [
      .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
    ])
    let isDirectory = values?.isDirectory ?? false
    var childCount: Int? = nil
    if isDirectory {
      childCount = (try? fileManager.contentsOfDirectory(atPath: url.path))?.count
    }
    let modified = values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
    return [
      "path": url.path,
      "name": url.lastPathComponent,
      "isDirectory": isDirectory,
      "sizeBytes": Int64(values?.fileSize ?? 0),
      "modifiedAt": isoFormatter.string(from: modified),
      "childCount": childCount as Any? ?? NSNull(),
      "isHidden": values?.isHidden ?? url.lastPathComponent.hasPrefix("."),
    ]
  }

  private func stat(_ path: String) -> [String: Any]? {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
      return nil
    }
    return entryJSON(URL(fileURLWithPath: path))
  }

  private func summarize(
    _ path: String,
    maxDepth: Int,
    maxEntries: Int
  ) throws -> [String: Any] {
    let root = URL(fileURLWithPath: path)
    guard let enumerator = fileManager.enumerator(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
      options: [],
      errorHandler: nil
    ) else {
      throw StorageError(code: "not_found", message: "Folder not found")
    }

    var bytes: Int64 = 0
    var items = 0
    var folders = 0
    var visited = 0

    while let url = enumerator.nextObject() as? URL {
      if enumerator.level > maxDepth {
        enumerator.skipDescendants()
        continue
      }
      visited += 1
      if visited > maxEntries { break }
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
      if values?.isDirectory == true {
        folders += 1
      } else {
        items += 1
        bytes += Int64(values?.fileSize ?? 0)
      }
    }
    return ["bytes": bytes, "items": items, "folders": folders]
  }

  private func search(_ path: String, query: String, limit: Int) throws -> [[String: Any]] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if needle.isEmpty { return [] }
    let root = URL(fileURLWithPath: path)
    guard let enumerator = fileManager.enumerator(
      at: root,
      includingPropertiesForKeys: [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
      ],
      options: [],
      errorHandler: nil
    ) else {
      throw StorageError(code: "not_found", message: "Folder not found")
    }

    var results: [[String: Any]] = []
    while let url = enumerator.nextObject() as? URL {
      if url.lastPathComponent.lowercased().contains(needle) {
        results.append(entryJSON(url))
        if results.count >= limit { break }
      }
    }
    return results
  }

  // MARK: - Mutations

  private func createFolder(parent: String, name: String) throws {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty, !clean.contains("/") else {
      throw StorageError(code: "invalid_name", message: "Invalid folder name")
    }
    let target = URL(fileURLWithPath: parent).appendingPathComponent(clean)
    guard !fileManager.fileExists(atPath: target.path) else {
      throw StorageError(code: "exists", message: "\"\(clean)\" already exists")
    }
    try fileManager.createDirectory(at: target, withIntermediateDirectories: false)
  }

  private func rename(_ path: String, newName: String) throws {
    let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty, !clean.contains("/") else {
      throw StorageError(code: "invalid_name", message: "Invalid name")
    }
    let source = URL(fileURLWithPath: path)
    let target = source.deletingLastPathComponent().appendingPathComponent(clean)
    guard !fileManager.fileExists(atPath: target.path) else {
      throw StorageError(code: "exists", message: "\"\(clean)\" already exists")
    }
    try fileManager.moveItem(at: source, to: target)
  }

  private func delete(_ path: String) throws {
    guard fileManager.fileExists(atPath: path) else { return }
    try fileManager.removeItem(at: URL(fileURLWithPath: path))
  }

  private func readBytes(_ path: String) throws -> FlutterStandardTypedData {
    let attributes = try fileManager.attributesOfItem(atPath: path)
    let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
    guard size <= StorageBridge.maxReadBytes else {
      throw StorageError(
        code: "too_large",
        message: "File is larger than 128 MB for in-memory encryption"
      )
    }
    return FlutterStandardTypedData(bytes: try Data(contentsOf: URL(fileURLWithPath: path)))
  }

  private func writeBytes(_ path: String, data: Data) throws {
    let url = URL(fileURLWithPath: path)
    try data.write(to: url, options: .atomic)
  }

  private func hashFile(_ path: String) throws -> String {
    guard let handle = FileHandle(forReadingAtPath: path) else {
      throw StorageError(code: "io", message: "Cannot read file")
    }
    defer { try? handle.close() }
    var hasher = SHA256()
    while autoreleasepool(invoking: {
      let chunk = handle.readData(ofLength: StorageBridge.bufferSize)
      if chunk.isEmpty { return false }
      hasher.update(data: chunk)
      return true
    }) {}

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Transfers

  private func startTransfer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let taskId = args["taskId"] as? String,
          let destination = args["destination"] as? String else {
      result(FlutterError(code: "invalid", message: "Missing transfer arguments", details: nil))
      return
    }
    let sources = args["sources"] as? [[String: Any]] ?? []
    let move = args["move"] as? Bool ?? false
    let total = sources.reduce(Int64(0)) { partial, entry in
      (entry["isDirectory"] as? Bool == true)
        ? partial
        : partial + ((entry["sizeBytes"] as? NSNumber)?.int64Value ?? 0)
    }

    transferState[taskId] = "running"
    ioQueue.async { [weak self] in
      guard let self else { return }
      var done: Int64 = 0
      var items = 0
      do {
        let destinationURL = URL(fileURLWithPath: destination)
        for source in sources {
          guard let sourcePath = source["path"] as? String else { continue }
          let name = (source["name"] as? String)
            ?? URL(fileURLWithPath: sourcePath).lastPathComponent
          try self.checkState(taskId)
          let target = destinationURL.appendingPathComponent(name)
          if self.fileManager.fileExists(atPath: target.path) {
            try self.fileManager.removeItem(at: target)
          }
          if source["isDirectory"] as? Bool == true {
            try self.fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: target)
            done += ((source["folderBytes"] as? NSNumber)?.int64Value ?? 0)
          } else {
            try self.fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: target)
            done += ((source["sizeBytes"] as? NSNumber)?.int64Value ?? 0)
          }
          items += 1
          self.report(taskId: taskId, done: done, total: total, name: name)
          if move {
            try self.delete(sourcePath)
          }
        }
        DispatchQueue.main.async {
          result(["bytes": done, "items": items])
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
        }
      }
      self.transferState.removeValue(forKey: taskId)
    }
  }

  private func checkState(_ taskId: String) throws {
    while transferState[taskId] == "paused" {
      Thread.sleep(forTimeInterval: 0.12)
    }
    if transferState[taskId] == "cancelled" {
      throw StorageError(code: "cancelled", message: "Transfer cancelled")
    }
  }

  private func report(taskId: String, done: Int64, total: Int64, name: String) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("transferProgress", arguments: [
        "taskId": taskId,
        "doneBytes": done,
        "totalBytes": total,
        "currentFile": name,
        "bytesPerSecond": 0.0,
      ])
    }
  }

  // MARK: - Benchmark

  private func startBenchmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let volumeId = args["volumeId"] as? String,
          let volume = volumes().first(where: { ($0["id"] as? String) == volumeId }),
          let root = volume["mountPath"] as? String else {
      result(FlutterError(code: "invalid", message: "Unknown drive", details: nil))
      return
    }

    ioQueue.async { [weak self] in
      guard let self else { return }
      let directory = URL(fileURLWithPath: root)
      let testFile = directory.appendingPathComponent(".drivepulse_bench_\(Int(Date().timeIntervalSince1970)).bin")
      let chunk = Data((0..<StorageBridge.bufferSize).map { UInt8($0 % 251) })
      let totalBytes: Int64 = 8 * 1024 * 1024
      do {
        let writeStart = Date()
        self.fileManager.createFile(atPath: testFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: testFile)
        for _ in 0..<(totalBytes / Int64(chunk.count)) {
          try handle.write(contentsOf: chunk)
        }
        try handle.synchronize()
        try handle.close()
        let writeSeconds = max(Date().timeIntervalSince(writeStart), 0.001)

        let readStart = Date()
        let reader = try FileHandle(forReadingFrom: testFile)
        while true {
          let chunkRead = try reader.read(upToCount: StorageBridge.bufferSize)
          if chunkRead == nil || chunkRead!.isEmpty { break }
        }
        try reader.close()
        let readSeconds = max(Date().timeIntervalSince(readStart), 0.001)
        try? self.fileManager.removeItem(at: testFile)

        let writeMbps = (Double(totalBytes) / 1_000_000.0) / writeSeconds
        let readMbps = (Double(totalBytes) / 1_000_000.0) / readSeconds
        let total = (volume["totalBytes"] as? NSNumber)?.int64Value ?? 0
        let free = (volume["freeBytes"] as? NSNumber)?.int64Value ?? 0
        let freeFraction = total > 0 ? Double(free) / Double(total) : 1.0
        var health = 100
        if writeMbps < 8 { health -= 35 } else if writeMbps < 20 { health -= 15 }
        if freeFraction < 0.05 { health -= 15 } else if freeFraction < 0.15 { health -= 5 }
        health = min(100, max(35, health))

        DispatchQueue.main.async {
          result([
            "readMbps": readMbps,
            "writeMbps": writeMbps,
            "latencyMs": 0.0,
            "healthPercent": health,
            "smartSupported": false,
            "notes": [
              "Measured with an 8 MB sequential write and read-back.",
              "iOS does not expose S.M.A.R.T. data for external media.",
            ],
          ])
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - Pickers

  private func pickDirectory(result: @escaping FlutterResult) {
    pendingFolder = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    present(picker)
  }

  private func pickFiles(result: @escaping FlutterResult, multiple: Bool) {
    pendingFiles = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = multiple
    present(picker)
  }

  private func present(_ picker: UIViewController) {
    DispatchQueue.main.async {
      guard let root = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
        .first?.rootViewController else { return }
      var top = root
      while let presented = top.presentedViewController {
        top = presented
      }
      top.present(picker, animated: true)
    }
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    if let folderResult = pendingFolder {
      pendingFolder = nil
      guard let url = urls.first else {
        folderResult(nil)
        return
      }
      _ = url.startAccessingSecurityScopedResource()
      do {
        let data = try url.bookmarkData(
          options: .minimalBookmark,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        bookmarks.append(BookmarkRecord(label: url.lastPathComponent, data: data))
        saveBookmarks()
        folderResult(entryJSON(url).merging(["path": url.path]) { _, new in new })
        eventSink?(volumes())
      } catch {
        folderResult(FlutterError(code: "bookmark", message: error.localizedDescription, details: nil))
      }
      return
    }

    if let filesResult = pendingFiles {
      pendingFiles = nil
      let entries = urls.map { url -> [String: Any] in
        _ = url.startAccessingSecurityScopedResource()
        return entryJSON(url)
      }
      filesResult(entries)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingFolder?(nil)
    pendingFolder = nil
    pendingFiles?([])
    pendingFiles = nil
  }

  // MARK: - Bookmarks

  private func loadBookmarks() {
    guard let stored = UserDefaults.standard.array(forKey: StorageBridge.bookmarksKey)
      as? [[String: Any]] else { return }
    bookmarks = stored.compactMap { entry in
      guard let label = entry["label"] as? String,
            let data = entry["data"] as? Data else { return nil }
      return BookmarkRecord(label: label, data: data)
    }
  }

  private func saveBookmarks() {
    let stored: [[String: Any]] = bookmarks.map { ["label": $0.label, "data": $0.data] }
    UserDefaults.standard.set(stored, forKey: StorageBridge.bookmarksKey)
  }

  // MARK: - Stream

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(volumes())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - Helpers

  private func path(_ call: FlutterMethodCall) -> String {
    (call.arguments as? [String: Any])?["path"] as? String ?? ""
  }

  private func deviceInfo() -> [String: String] {
    let device = UIDevice.current
    return [
      "platform": "\(device.systemName) \(device.systemVersion)",
      "model": device.model,
      "os": device.systemName,
      "engine": "Native Swift bridge",
    ]
  }
}

private struct StorageError: Error {
  let code: String
  let message: String
}
