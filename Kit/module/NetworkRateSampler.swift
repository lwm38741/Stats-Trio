import Foundation

/// Cumulative counters and byte totals are distinct from bytes per second.
public struct NetworkRateSampler {
    public struct Sample {
        public let uploadBytes: Int64
        public let downloadBytes: Int64
        public let uploadRate: Int64
        public let downloadRate: Int64
    }
    private var previous: (upload: Int64, download: Int64, time: Double, scope: String)?
    public init() {}
    public mutating func reset() { previous = nil }
    public mutating func sample(upload: Int64, download: Int64, time: Double,
                                scope: String, maxBytesPerSecond: Double = 2_000_000_000) -> Sample {
        defer { previous = (upload, download, time, scope) }
        guard let previous, previous.scope == scope, time > previous.time,
              upload >= previous.upload, download >= previous.download else {
            return Sample(uploadBytes: 0, downloadBytes: 0, uploadRate: 0, downloadRate: 0)
        }
        let elapsed = time - previous.time
        let up = upload - previous.upload
        let down = download - previous.download
        let validUp = Double(up) <= maxBytesPerSecond * elapsed ? up : 0
        let validDown = Double(down) <= maxBytesPerSecond * elapsed ? down : 0
        return Sample(uploadBytes: validUp, downloadBytes: validDown,
                      uploadRate: Int64(Double(validUp) / elapsed),
                      downloadRate: Int64(Double(validDown) / elapsed))
    }
}
