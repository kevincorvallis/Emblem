import Foundation

enum SubprocessError: LocalizedError {
    case nonZeroExit(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let status, let output):
            return "Command failed (exit \(status)): \(output.prefix(500))"
        }
    }
}

/// Async wrapper around Process. Upstream ran waitUntilExit on the calling
/// thread; this never blocks the caller.
struct Subprocess {
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            // Drain the pipe while the process runs — a child that fills the
            // 64KB pipe buffer before exiting would otherwise deadlock, since
            // nothing reads until the termination handler.
            let buffer = OutputBuffer()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    buffer.append(chunk)
                }
            }

            process.terminationHandler = { finished in
                pipe.fileHandleForReading.readabilityHandler = nil
                if let remaining = try? pipe.fileHandleForReading.readToEnd() {
                    buffer.append(remaining)
                }
                let output = String(data: buffer.data, encoding: .utf8) ?? ""
                if finished.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: SubprocessError.nonZeroExit(
                        status: finished.terminationStatus, output: output))
                }
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Thread-safe accumulator shared by the readability and termination handlers.
private final class OutputBuffer: @unchecked Sendable {
    private var storage = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        storage.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
