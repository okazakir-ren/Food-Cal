import Foundation

/// 実機確認用の記録。誰が、いつ、歩数を読めたかを残す。
struct DiagnosticEvent: Codable, Equatable, Sendable, Identifiable {
    enum Source: String, Codable, Sendable, CaseIterable {
        case app = "本体"
        case background = "バックグラウンド"
        case widget = "ウィジェット"
    }

    /// 時刻は秒単位で保存するので、IDには使えない（同じ秒に書くと重なる）。
    var id = UUID()
    let at: Date
    let source: Source
    let action: String
    let steps: Int?
    /// HealthKitなどのエラー。例: "com.apple.healthkit/6"
    let error: String?

    var succeeded: Bool { error == nil }
}

struct DiagnosticSummary: Equatable, Sendable {
    let source: DiagnosticEvent.Source
    let total: Int
    let failed: Int
    let lastAt: Date?

    static func make(events: [DiagnosticEvent], since: Date) -> [DiagnosticSummary] {
        DiagnosticEvent.Source.allCases.map { source in
            let matched = events.filter { $0.source == source && $0.at >= since }
            return DiagnosticSummary(
                source: source,
                total: matched.count,
                failed: matched.filter { !$0.succeeded }.count,
                lastAt: matched.map(\.at).max()
            )
        }
    }
}

enum DiagnosticLog {
    private static let maxLines = 1000

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("diagnostics.jsonl")
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 本体とウィジェットは別プロセスなので、追記だけで書き足す。
    static func append(_ event: DiagnosticEvent) {
        guard let url = fileURL, var data = try? encoder.encode(event) else { return }
        data.append(0x0A)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    static func readAll() -> [DiagnosticEvent] {
        guard let url = fileURL, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            try? decoder.decode(DiagnosticEvent.self, from: Data(line.utf8))
        }
    }

    /// 本体の起動時に呼ぶ。古い行を捨てる。
    static func trim() {
        guard let url = fileURL, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n")
        guard lines.count > maxLines else { return }
        try? (lines.suffix(maxLines).joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    static func exportText() -> String {
        guard let url = fileURL, let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
}
