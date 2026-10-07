import Foundation

private let logStamp: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()

/// The single logging path: timestamped line on stderr (launchd redirects it to the log file).
func log(_ s: String) {
    FileHandle.standardError.write(Data("\(logStamp.string(from: Date())) ack05d: \(s)\n".utf8))
}
