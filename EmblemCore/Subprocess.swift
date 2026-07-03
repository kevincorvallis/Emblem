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

            process.terminationHandler = { finished in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
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
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
