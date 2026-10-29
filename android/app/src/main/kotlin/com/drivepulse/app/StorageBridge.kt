package com.drivepulse.app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.provider.OpenableColumns
import androidx.core.content.ContextCompat
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * DrivePulse native storage bridge (Android).
 *
 * Exposes StorageManager volumes, USB/OTG drives, SAF tree access, file
 * operations, streaming copy with progress, SHA-256 hashing and a local
 * read/write benchmark. Android forbids third-party apps from formatting or
 * forcibly unmounting removable media, so those actions stay in the system UI
 * and the Dart layer says so explicitly.
 */
class StorageBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val CHANNEL = "drivepulse/storage"
        private const val EVENTS = "drivepulse/volumes"
        private const val PREFS = "drivepulse_native"
        private const val KEY_TREES = "authorised_trees"
        private const val REQ_TREE = 4821
        private const val REQ_FILES = 4822
        private const val MAX_READ_BYTES = 128L * 1024 * 1024
        private const val BUFFER = 256 * 1024
        private const val PROGRESS_STEP = 512 * 1024
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val volumeChannel = EventChannel(messenger, EVENTS)
    private val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val transferState = ConcurrentHashMap<String, String>()
    private val executor = Executors.newFixedThreadPool(2)
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false
    private var pendingTreeResult: MethodChannel.Result? = null
    private var pendingFilesResult: MethodChannel.Result? = null

    private val mediaReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                eventSink?.success(listVolumes())
            } catch (_: Exception) {
                // A receiver must never crash the app.
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        volumeChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listVolumes" -> result.success(listVolumes())
                "refreshVolume" -> {
                    val id = call.argument<String>("volumeId")
                    result.success(listVolumes().firstOrNull { it["id"] == id })
                }
                "listDirectory" -> result.success(listDirectory(requiredPath(call)))
                "stat" -> result.success(statPath(requiredPath(call)))
                "summarize" -> result.success(
                    summarize(
                        requiredPath(call),
                        call.argument<Int>("maxDepth") ?: 8,
                        call.argument<Int>("maxEntries") ?: 40000,
                    ),
                )
                "search" -> result.success(
                    search(
                        requiredPath(call),
                        call.argument<String>("query") ?: "",
                        call.argument<Int>("limit") ?: 300,
                    ),
                )
                "createFolder" -> {
                    createFolder(
                        call.argument<String>("parent")
                            ?: throw IllegalArgumentException("Missing parent"),
                        call.argument<String>("name")
                            ?: throw IllegalArgumentException("Missing name"),
                    )
                    result.success(null)
                }
                "rename" -> {
                    renamePath(
                        requiredPath(call),
                        call.argument<String>("newName")
                            ?: throw IllegalArgumentException("Missing newName"),
                    )
                    result.success(null)
                }
                "delete" -> {
                    val entries = call.argument<List<*>>("entries") ?: emptyList<Any>()
                    for (entry in entries) {
                        val map = entry as? Map<*, *> ?: continue
                        val path = map["path"] as? String ?: continue
                        deletePath(path)
                    }
                    result.success(null)
                }
                "transfer" -> startTransfer(call, result)
                "pauseTransfer" -> {
                    val taskId = call.argument<String>("taskId")
                        ?: throw IllegalArgumentException("Missing taskId")
                    transferState[taskId] =
                        if (call.argument<Boolean>("paused") == true) "paused" else "running"
                    result.success(null)
                }
                "cancelTransfer" -> {
                    val taskId = call.argument<String>("taskId")
                        ?: throw IllegalArgumentException("Missing taskId")
                    transferState[taskId] = "cancelled"
                    result.success(null)
                }
                "benchmark" -> startBenchmark(call, result)
                "eject" -> result.success(true)
                "readFile" -> result.success(readBytes(requiredPath(call)))
                "writeFile" -> {
                    writeBytes(
                        requiredPath(call),
                        call.argument<ByteArray>("bytes") ?: ByteArray(0),
                    )
                    result.success(null)
                }
                "hashFile" -> result.success(hashFile(requiredPath(call)))
                "exists" -> result.success(exists(requiredPath(call)))
                "pickDirectory" -> pickDirectory(result)
                "pickFiles" -> pickFiles(result, call.argument<Boolean>("multiple") ?: true)
                "deviceInfo" -> result.success(deviceInfo())
                else -> result.notImplemented()
            }
        } catch (error: SecurityException) {
            result.error(
                "permission",
                error.message ?: "Storage permission denied. Grant folder access with the + button.",
                null,
            )
        } catch (error: Exception) {
            result.error("io", error.message ?: "Storage operation failed", null)
        }
    }

    // ---------------------------------------------------------------------
    // Volumes
    // ---------------------------------------------------------------------

    private fun listVolumes(): List<Map<String, Any?>> {
        val volumes = mutableListOf<Map<String, Any?>>()
        val primary = Environment.getExternalStorageDirectory()
        val primaryStat = try {
            StatFs(primary.absolutePath)
        } catch (_: Exception) {
            null
        }
        volumes.add(
            volumeJson(
                id = "internal",
                label = "Internal storage",
                total = primaryStat?.totalBytes ?: 0L,
                free = primaryStat?.availableBytes ?: 0L,
                kind = "internal",
                bus = "Internal",
                protocol = "eMMC / UFS",
                serial = "",
                mount = primary.absolutePath,
            ),
        )

        val manager = activity.getSystemService(Context.STORAGE_SERVICE) as? StorageManager
        if (manager != null) {
            for (volume in manager.storageVolumes) {
                if (volume.isPrimary || !volume.isRemovable) continue
                val directory: File? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    volume.directory
                } else {
                    @Suppress("DEPRECATION")
                    volume.uuid?.let { File("/storage/$it") }
                }
                if (directory == null || !directory.exists()) continue
                val stat = try {
                    StatFs(directory.absolutePath)
                } catch (_: Exception) {
                    null
                }
                val description = volume.getDescription(activity) ?: "Removable drive"
                val id = volume.uuid ?: directory.name
                val isSd = description.contains("SD", ignoreCase = true) ||
                    directory.name.equals("sdcard1", ignoreCase = true)
                volumes.add(
                    volumeJson(
                        id = "vol:$id",
                        label = description,
                        total = stat?.totalBytes ?: 0L,
                        free = stat?.availableBytes ?: 0L,
                        kind = if (isSd) "sdCard" else "usbFlash",
                        bus = "USB OTG",
                        protocol = "USB",
                        serial = volume.uuid ?: "",
                        mount = directory.absolutePath,
                    ),
                )
            }
        }

        // Folders the user explicitly authorised through SAF.
        val trees = prefs.getStringSet(KEY_TREES, emptySet()) ?: emptySet()
        for (tree in trees) {
            val uri = try {
                Uri.parse(tree)
            } catch (_: Exception) {
                continue
            }
            val doc = DocumentFile.fromTreeUri(activity, uri) ?: continue
            volumes.add(
                mapOf(
                    "id" to "tree:$tree",
                    "label" to (doc.name ?: "Authorised folder"),
                    "fileSystem" to "SAF",
                    "totalBytes" to 0L,
                    "freeBytes" to 0L,
                    "kind" to "externalSsd",
                    "busLabel" to "SAF",
                    "protocolLabel" to "Authorised folder",
                    "serial" to "",
                    "mountPath" to tree,
                    "readMbps" to 0.0,
                    "writeMbps" to 0.0,
                    "healthPercent" to 100,
                    "isReadOnly" to !doc.canWrite(),
                    "isConnected" to true,
                    "smartSupported" to false,
                    "lastSeen" to iso(System.currentTimeMillis()),
                ),
            )
        }
        return volumes
    }

    private fun volumeJson(
        id: String,
        label: String,
        total: Long,
        free: Long,
        kind: String,
        bus: String,
        protocol: String,
        serial: String,
        mount: String,
    ): Map<String, Any?> = mapOf(
        "id" to id,
        "label" to label,
        "fileSystem" to filesystemLabel(mount),
        "totalBytes" to max(0L, total),
        "freeBytes" to max(0L, free),
        "kind" to kind,
        "busLabel" to bus,
        "protocolLabel" to protocol,
        "serial" to serial,
        "mountPath" to mount,
        "readMbps" to 0.0,
        "writeMbps" to 0.0,
        "healthPercent" to if (total > 0) 100 else 0,
        "isReadOnly" to (!File(mount).canWrite() && !isContent(mount)),
        "isConnected" to true,
        "smartSupported" to false,
        "lastSeen" to iso(System.currentTimeMillis()),
    )

    private fun filesystemLabel(path: String): String {
        // Android does not expose the filesystem of removable volumes to apps.
        return if (isContent(path)) "SAF" else "unknown"
    }

    // ---------------------------------------------------------------------
    // Directory access
    // ---------------------------------------------------------------------

    private fun listDirectory(path: String): List<Map<String, Any?>> {
        if (isContent(path)) {
            val doc = documentFor(path)
                ?: throw IllegalArgumentException("Folder is no longer authorised")
            if (!doc.isDirectory) throw IllegalArgumentException("Not a folder: $path")
            return doc.listFiles().map { documentJson(it) }
        }
        val dir = File(path)
        if (!dir.exists()) throw IllegalArgumentException("Folder not found: $path")
        if (!dir.isDirectory) throw IllegalArgumentException("Not a folder: $path")
        val files = dir.listFiles()
            ?: throw SecurityException(
                "Android scoped storage blocked $path. Grant folder access with the + button.",
            )
        return files.map { fileJson(it) }
    }

    private fun statPath(path: String): Map<String, Any?>? {
        return try {
            if (isContent(path)) {
                val doc = documentFor(path) ?: return null
                documentJson(doc)
            } else {
                val file = File(path)
                if (!file.exists()) null else fileJson(file)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun fileJson(file: File): Map<String, Any?> = mapOf(
        "path" to file.absolutePath,
        "name" to file.name,
        "isDirectory" to file.isDirectory,
        "sizeBytes" to if (file.isDirectory) 0L else file.length(),
        "modifiedAt" to iso(file.lastModified()),
        "childCount" to if (file.isDirectory) file.listFiles()?.size else null,
        "isHidden" to file.name.startsWith("."),
    )

    private fun documentJson(doc: DocumentFile): Map<String, Any?> = mapOf(
        "path" to doc.uri.toString(),
        "name" to (doc.name ?: "Unnamed"),
        "isDirectory" to doc.isDirectory,
        "sizeBytes" to if (doc.isDirectory) 0L else doc.length(),
        "modifiedAt" to iso(if (doc.lastModified() > 0) doc.lastModified() else System.currentTimeMillis()),
        "childCount" to null,
        "isHidden" to (doc.name ?: "").startsWith("."),
    )

    private fun summarize(path: String, maxDepth: Int, maxEntries: Int): Map<String, Any?> {
        var bytes = 0L
        var items = 0
        var folders = 0
        var visited = 0
        val queue = ArrayDeque<Pair<String, Int>>()
        queue.add(path to 0)
        while (queue.isNotEmpty() && visited < maxEntries) {
            val (dir, depth) = queue.removeFirst()
            val children = try {
                listDirectory(dir)
            } catch (_: Exception) {
                continue
            }
            for (child in children) {
                visited++
                val isDir = child["isDirectory"] == true
                if (isDir) {
                    folders++
                    if (depth < maxDepth) {
                        queue.add((child["path"] as String) to depth + 1)
                    }
                } else {
                    items++
                    bytes += (child["sizeBytes"] as? Number)?.toLong() ?: 0L
                }
                if (visited >= maxEntries) break
            }
        }
        return mapOf("bytes" to bytes, "items" to items, "folders" to folders)
    }

    private fun search(root: String, query: String, limit: Int): List<Map<String, Any?>> {
        val needle = query.trim().lowercase(Locale.US)
        if (needle.isEmpty()) return emptyList()
        val results = mutableListOf<Map<String, Any?>>()
        val queue = ArrayDeque<String>()
        val visited = HashSet<String>()
        queue.add(root)
        while (queue.isNotEmpty() && results.size < limit) {
            val dir = queue.removeFirst()
            if (!visited.add(dir)) continue
            val children = try {
                listDirectory(dir)
            } catch (_: Exception) {
                continue
            }
            for (child in children) {
                val name = (child["name"] as? String) ?: continue
                if (name.lowercase(Locale.US).contains(needle)) results.add(child)
                if (child["isDirectory"] == true) queue.add(child["path"] as String)
                if (results.size >= limit) break
            }
        }
        return results
    }

    private fun createFolder(parent: String, name: String) {
        val clean = name.trim()
        if (clean.isEmpty() || clean.contains("/")) {
            throw IllegalArgumentException("Invalid folder name")
        }
        if (isContent(parent)) {
            val doc = documentFor(parent)
                ?: throw IllegalArgumentException("Folder is no longer authorised")
            if (doc.findFile(clean) != null) {
                throw IllegalArgumentException("\"$clean\" already exists")
            }
            doc.createDirectory(clean)
                ?: throw IllegalStateException("Could not create folder")
        } else {
            val dir = File(parent, clean)
            if (dir.exists()) throw IllegalArgumentException("\"$clean\" already exists")
            if (!dir.mkdirs()) throw IllegalStateException("Could not create folder")
        }
    }

    private fun renamePath(path: String, newName: String) {
        val clean = newName.trim()
        if (clean.isEmpty() || clean.contains("/")) {
            throw IllegalArgumentException("Invalid name")
        }
        if (isContent(path)) {
            val doc = documentFor(path)
                ?: throw IllegalArgumentException("File is no longer authorised")
            if (!doc.renameTo(clean)) throw IllegalStateException("Rename failed")
        } else {
            val file = File(path)
            if (!file.exists()) throw IllegalArgumentException("File no longer exists")
            val target = File(file.parentFile, clean)
            if (target.exists()) throw IllegalArgumentException("\"$clean\" already exists")
            if (!file.renameTo(target)) throw IllegalStateException("Rename failed")
        }
    }

    private fun deletePath(path: String) {
        if (isContent(path)) {
            val doc = documentFor(path) ?: return
            if (!doc.delete()) throw IllegalStateException("Delete failed")
        } else {
            val file = File(path)
            if (file.exists() && !file.deleteRecursively()) {
                throw IllegalStateException("Delete failed")
            }
        }
    }

    private fun exists(path: String): Boolean = try {
        if (isContent(path)) documentFor(path)?.exists() == true else File(path).exists()
    } catch (_: Exception) {
        false
    }

    // ---------------------------------------------------------------------
    // Transfer
    // ---------------------------------------------------------------------

    private fun startTransfer(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")
            ?: throw IllegalArgumentException("Missing taskId")
        val sources = call.argument<List<*>>("sources") ?: emptyList<Any>()
        val destination = call.argument<String>("destination")
            ?: throw IllegalArgumentException("Missing destination")
        val move = call.argument<Boolean>("move") ?: false

        transferState[taskId] = "running"
        executor.execute {
            var done = 0L
            var items = 0
            var total = 0L
            for (entry in sources) {
                val map = entry as? Map<*, *> ?: continue
                val isDir = map["isDirectory"] == true
                if (!isDir) total += (map["sizeBytes"] as? Number)?.toLong() ?: 0L
            }
            try {
                for (entry in sources) {
                    val map = entry as? Map<*, *> ?: continue
                    val path = map["path"] as? String ?: continue
                    val name = map["name"] as? String ?: nameOf(path)
                    checkState(taskId)
                    if (map["isDirectory"] == true) {
                        copyTree(path, destination, taskId) { delta ->
                            done += delta
                            report(taskId, done, total, name)
                        }
                    } else {
                        copyFile(path, destination, name, taskId) { delta ->
                            done += delta
                            report(taskId, done, total, name)
                        }
                    }
                    items++
                    if (move) deletePath(path)
                }
                activity.runOnUiThread {
                    result.success(mapOf("bytes" to done, "items" to items))
                }
            } catch (error: InterruptedException) {
                activity.runOnUiThread {
                    result.error("cancelled", "Transfer cancelled", null)
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error("io", error.message ?: "Transfer failed", null)
                }
            } finally {
                transferState.remove(taskId)
            }
        }
    }

    private fun checkState(taskId: String) {
        while (transferState[taskId] == "paused") {
            Thread.sleep(120)
        }
        if (transferState[taskId] == "cancelled") {
            throw InterruptedException("cancelled")
        }
    }

    private fun report(taskId: String, done: Long, total: Long, name: String) {
        activity.runOnUiThread {
            channel.invokeMethod(
                "transferProgress",
                mapOf(
                    "taskId" to taskId,
                    "doneBytes" to done,
                    "totalBytes" to total,
                    "currentFile" to name,
                    "bytesPerSecond" to 0.0,
                ),
            )
        }
    }

    private fun copyFile(
        srcPath: String,
        destinationDir: String,
        name: String,
        taskId: String,
        onBytes: (Long) -> Unit,
    ) {
        val input = openInput(srcPath)
            ?: throw IllegalArgumentException("Cannot read $srcPath")
        input.use { source ->
            val output = openOutput(destinationDir, name)
                ?: throw IllegalStateException("Cannot write to $destinationDir")
            output.use { target ->
                val buffer = ByteArray(BUFFER)
                var pending = 0L
                while (true) {
                    checkState(taskId)
                    val read = source.read(buffer)
                    if (read <= 0) break
                    target.write(buffer, 0, read)
                    pending += read
                    if (pending >= PROGRESS_STEP) {
                        onBytes(pending)
                        pending = 0
                    }
                }
                target.flush()
                if (pending > 0) onBytes(pending)
            }
        }
    }

    private fun copyTree(
        srcPath: String,
        destinationDir: String,
        taskId: String,
        onBytes: (Long) -> Unit,
    ) {
        val name = nameOf(srcPath)
        val newDir = makeDirectory(destinationDir, name)
        for (child in listDirectory(srcPath)) {
            checkState(taskId)
            val childPath = child["path"] as? String ?: continue
            val childName = child["name"] as? String ?: nameOf(childPath)
            if (child["isDirectory"] == true) {
                copyTree(childPath, newDir, taskId, onBytes)
            } else {
                copyFile(childPath, newDir, childName, taskId, onBytes)
            }
        }
    }

    private fun openInput(path: String): InputStream? {
        return if (isContent(path)) {
            activity.contentResolver.openInputStream(Uri.parse(path))
        } else {
            FileInputStream(File(path))
        }
    }

    private fun openOutput(directory: String, name: String): OutputStream? {
        return if (isContent(directory)) {
            val parent = documentFor(directory) ?: return null
            val existing = parent.findFile(name)
            existing?.delete()
            val file = parent.createFile(mimeOf(name), name) ?: return null
            activity.contentResolver.openOutputStream(file.uri)
        } else {
            val target = File(directory, name)
            target.parentFile?.mkdirs()
            FileOutputStream(target)
        }
    }

    private fun makeDirectory(directory: String, name: String): String {
        return if (isContent(directory)) {
            val parent = documentFor(directory)
                ?: throw IllegalArgumentException("Folder is no longer authorised")
            val child = parent.findFile(name) ?: parent.createDirectory(name)
                ?: throw IllegalStateException("Could not create folder")
            child.uri.toString()
        } else {
            val dir = File(directory, name)
            dir.mkdirs()
            dir.absolutePath
        }
    }

    private fun nameOf(path: String): String {
        return if (isContent(path)) {
            documentFor(path)?.name ?: "file"
        } else {
            File(path).name
        }
    }

    // ---------------------------------------------------------------------
    // Encryption helpers
    // ---------------------------------------------------------------------

    private fun readBytes(path: String): ByteArray {
        if (!isContent(path)) {
            val file = File(path)
            if (file.length() > MAX_READ_BYTES) {
                throw IllegalArgumentException("File is larger than 128 MB. Encrypt it in a desktop tool.")
            }
            return file.readBytes()
        }
        val doc = documentFor(path)
            ?: throw IllegalArgumentException("File is no longer authorised")
        if (doc.length() > MAX_READ_BYTES) {
            throw IllegalArgumentException("File is larger than 128 MB.")
        }
        return activity.contentResolver.openInputStream(doc.uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Cannot read file")
    }

    private fun writeBytes(path: String, bytes: ByteArray) {
        if (isContent(path)) {
            val parentPath = path.substringBeforeLast('/')
            val name = nameOf(path)
            val output = openOutput(parentPath, name)
                ?: throw IllegalStateException("Cannot write file")
            output.use { it.write(bytes) }
        } else {
            val file = File(path)
            file.parentFile?.mkdirs()
            file.writeBytes(bytes)
        }
    }

    private fun hashFile(path: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val input = openInput(path) ?: throw IllegalArgumentException("Cannot read file")
        input.use { stream ->
            val buffer = ByteArray(BUFFER)
            while (true) {
                val read = stream.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    // ---------------------------------------------------------------------
    // Benchmark
    // ---------------------------------------------------------------------

    private fun startBenchmark(call: MethodCall, result: MethodChannel.Result) {
        val volumeId = call.argument<String>("volumeId")
            ?: throw IllegalArgumentException("Missing volumeId")
        executor.execute {
            try {
                val volume = listVolumes().firstOrNull { it["id"] == volumeId }
                    ?: throw IllegalArgumentException("Unknown drive")
                val root = volume["mountPath"] as? String
                    ?: throw IllegalArgumentException("Drive is not mounted")
                if (isContent(root)) {
                    throw IllegalStateException(
                        "Benchmark needs direct filesystem access. Use a mounted volume.",
                    )
                }
                val directory = File(root)
                if (!directory.canWrite()) throw SecurityException("Drive is read-only")
                val testFile = File(directory, ".drivepulse_bench_${System.currentTimeMillis()}.bin")
                val chunk = ByteArray(BUFFER) { index -> (index % 251).toByte() }
                val totalBytes = 8L * 1024 * 1024
                val writeStart = System.nanoTime()
                FileOutputStream(testFile).use { output ->
                    repeat((totalBytes / chunk.size).toInt()) { output.write(chunk) }
                    output.flush()
                    output.fd.sync()
                }
                val writeSeconds = (System.nanoTime() - writeStart) / 1_000_000_000.0
                val readStart = System.nanoTime()
                FileInputStream(testFile).use { input ->
                    val buffer = ByteArray(chunk.size)
                    while (input.read(buffer) > 0) {
                        // Read until EOF.
                    }
                }
                val readSeconds = (System.nanoTime() - readStart) / 1_000_000_000.0
                testFile.delete()

                val writeMbps = (totalBytes / 1_000_000.0) / max(writeSeconds, 0.001)
                val readMbps = (totalBytes / 1_000_000.0) / max(readSeconds, 0.001)
                val total = (volume["totalBytes"] as? Number)?.toLong() ?: 0L
                val free = (volume["freeBytes"] as? Number)?.toLong() ?: 0L
                val freeFraction = if (total > 0) free.toDouble() / total else 1.0
                var health = 100
                if (writeMbps < 8) health -= 35 else if (writeMbps < 20) health -= 15
                if (freeFraction < 0.05) health -= 15 else if (freeFraction < 0.15) health -= 5
                health = health.coerceIn(35, 100)

                activity.runOnUiThread {
                    result.success(
                        mapOf(
                            "readMbps" to readMbps,
                            "writeMbps" to writeMbps,
                            "latencyMs" to 0.0,
                            "healthPercent" to health,
                            "smartSupported" to false,
                            "notes" to listOf(
                                "Measured with an 8 MB sequential write and read-back.",
                                "S.M.A.R.T. is not exposed to apps on Android.",
                            ),
                        ),
                    )
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error("io", error.message ?: "Benchmark failed", null)
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Pickers
    // ---------------------------------------------------------------------

    private fun pickDirectory(result: MethodChannel.Result) {
        pendingTreeResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        activity.startActivityForResult(intent, REQ_TREE)
    }

    private fun pickFiles(result: MethodChannel.Result, multiple: Boolean) {
        pendingFilesResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        activity.startActivityForResult(intent, REQ_FILES)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_TREE) {
            val result = pendingTreeResult
            pendingTreeResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result?.success(null)
                return
            }
            try {
                activity.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // Read-only grants are still useful.
            }
            val trees = HashSet(prefs.getStringSet(KEY_TREES, emptySet()) ?: emptySet())
            trees.add(uri.toString())
            prefs.edit().putStringSet(KEY_TREES, trees).apply()

            val doc = DocumentFile.fromTreeUri(activity, uri)
            result?.success(
                mapOf(
                    "path" to uri.toString(),
                    "name" to (doc?.name ?: "Authorised folder"),
                    "isDirectory" to true,
                    "sizeBytes" to 0L,
                    "modifiedAt" to iso(System.currentTimeMillis()),
                    "isHidden" to false,
                ),
            )
            eventSink?.success(listVolumes())
            return
        }

        if (requestCode == REQ_FILES) {
            val result = pendingFilesResult
            pendingFilesResult = null
            if (resultCode != Activity.RESULT_OK || data == null) {
                result?.success(emptyList<Map<String, Any?>>())
                return
            }
            val uris = mutableListOf<Uri>()
            val clip = data.clipData
            if (clip != null) {
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.let { uris.add(it) }
                }
            } else {
                data.data?.let { uris.add(it) }
            }
            val entries = uris.mapNotNull { uri ->
                try {
                    activity.contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                } catch (_: SecurityException) {
                    // Non-persistable grants still work for this session.
                }
                documentJson(
                    DocumentFile.fromSingleUri(activity, uri)
                        ?: return@mapNotNull null,
                ).plus("path" to uri.toString())
            }
            result?.success(entries)
        }
    }

    private fun deviceInfo(): Map<String, String> = mapOf(
        "platform" to "Android ${Build.VERSION.RELEASE}",
        "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
        "os" to "API ${Build.VERSION.SDK_INT}",
        "engine" to "Native Kotlin bridge",
    )

    // ---------------------------------------------------------------------
    // Platform helpers
    // ---------------------------------------------------------------------

    private fun requiredPath(call: MethodCall): String =
        call.argument<String>("path") ?: throw IllegalArgumentException("Missing path")

    private fun isContent(path: String): Boolean = path.startsWith("content://")

    private fun documentFor(path: String): DocumentFile? {
        return try {
            val uri = Uri.parse(path)
            if (path.contains("/tree/")) {
                DocumentFile.fromTreeUri(activity, uri)
                    ?: DocumentFile.fromSingleUri(activity, uri)
            } else {
                DocumentFile.fromSingleUri(activity, uri)
                    ?: DocumentFile.fromTreeUri(activity, uri)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun mimeOf(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase(Locale.US)
        return when (extension) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "heic" -> "image/heic"
            "mp4", "m4v" -> "video/mp4"
            "mov" -> "video/quicktime"
            "mkv" -> "video/x-matroska"
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "flac" -> "audio/flac"
            "m4a" -> "audio/mp4"
            "pdf" -> "application/pdf"
            "zip" -> "application/zip"
            "txt", "md", "log" -> "text/plain"
            "json" -> "application/json"
            "xml" -> "application/xml"
            "apk" -> "application/vnd.android.package-archive"
            else -> "application/octet-stream"
        }
    }

    private fun iso(millis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(millis))
    }

    // ---------------------------------------------------------------------
    // Volume event stream
    // ---------------------------------------------------------------------

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_MEDIA_MOUNTED)
            addAction(Intent.ACTION_MEDIA_UNMOUNTED)
            addAction(Intent.ACTION_MEDIA_EJECT)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            addDataScheme("file")
        }
        ContextCompat.registerReceiver(
            activity,
            mediaReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiverRegistered = true
        try {
            sink?.success(listVolumes())
        } catch (_: Exception) {
            // Ignore initial emit failures.
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (receiverRegistered) {
            try {
                activity.unregisterReceiver(mediaReceiver)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
            receiverRegistered = false
        }
    }

    fun dispose() {
        onCancel(null)
        channel.setMethodCallHandler(null)
        volumeChannel.setStreamHandler(null)
        executor.shutdownNow()
    }
}
