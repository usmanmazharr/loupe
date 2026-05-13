import Foundation

/// Encodes and decodes length-prefixed JSON frames over a byte stream.
///
/// Frame layout:
///   [4 bytes: big-endian UInt32 — payload length][N bytes: JSON]
enum RemoteFraming {

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Encodes an envelope into a framed Data blob ready to send over TCP.
    static func encode(_ envelope: RemoteEnvelope) throws -> Data {
        let json = try encoder.encode(envelope)
        var length = UInt32(json.count).bigEndian
        var frame  = Data(bytes: &length, count: 4)
        frame.append(json)
        return frame
    }

    /// Reads all complete frames from `buffer`, removes consumed bytes in-place,
    /// and returns the decoded envelopes.  Any trailing partial frame stays in `buffer`.
    static func decode(buffer: inout Data) throws -> [RemoteEnvelope] {
        var results: [RemoteEnvelope] = []
        while buffer.count >= 4 {
            let lengthBytes = Array(buffer.prefix(4))
            let length = Int(
                (UInt32(lengthBytes[0]) << 24) |
                (UInt32(lengthBytes[1]) << 16) |
                (UInt32(lengthBytes[2]) << 8)  |
                 UInt32(lengthBytes[3])
            )
            guard buffer.count >= 4 + length else { break }
            let json     = buffer.subdata(in: 4 ..< 4 + length)
            buffer.removeFirst(4 + length)
            let envelope = try decoder.decode(RemoteEnvelope.self, from: json)
            results.append(envelope)
        }
        return results
    }
}
