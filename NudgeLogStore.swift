import Foundation
import Combine

struct NudgeEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let message: String
    let reasons: [String]
}

final class NudgeLogStore: ObservableObject {
    static let shared = NudgeLogStore()

    @Published private(set) var entries: [NudgeEntry] = [] { didSet { persist() } }

    private let url: URL

    private init() {
        let fn = "GaitCoach.nudges.v1.json"
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fn)
        load()
    }

    func add(message: String, reasons: [String]) {
        var list = entries
        list.append(NudgeEntry(id: UUID(), date: Date(), message: message, reasons: reasons))
        entries = list.suffix(50) // cap
    }

    // persistence
    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([NudgeEntry].self, from: data) else { return }
        entries = list
    }
}

