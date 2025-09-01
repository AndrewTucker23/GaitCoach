import Foundation
import Combine

struct PlannedExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var exercise: ExerciseItem
    var minutes: Int
    var isDone: Bool

    init(exercise: ExerciseItem, minutes: Int, isDone: Bool = false) {
        self.id = UUID()
        self.exercise = exercise
        self.minutes = minutes
        self.isDone = isDone
    }
}

final class ExercisePlanStore: ObservableObject {
    static let shared = ExercisePlanStore()

    @Published private(set) var today: [PlannedExercise] = [] {
        didSet { persist() }
    }

    private let url: URL

    private init() {
        let fn = "GaitCoach.plan.today.v1.json"
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fn)
        load()
    }

    // MARK: - CRUD

    func addExercises(_ items: [ExerciseItem], defaultMinutes: Int? = nil) {
        for ex in items {
            let mins = defaultMinutes ?? ExerciseCatalog.defaultMinutes(for: ex)
            today.append(PlannedExercise(exercise: ex, minutes: mins))
        }
    }

    func remove(atOffsets offsets: IndexSet) {
        today.remove(atOffsets: offsets)
    }

    func move(fromOffsets src: IndexSet, toOffset dst: Int) {
        today.move(fromOffsets: src, toOffset: dst)
    }

    func toggleDone(_ id: UUID) {
        guard let idx = today.firstIndex(where: { $0.id == id }) else { return }
        today[idx].isDone.toggle()
    }

    func resetForToday() {
        today.removeAll()
        persist()
    }

    // MARK: - Coach auto-fill (≤ 3, consistent with Coach view)

    func generateFromPatterns(_ patterns: [String]) {
        let preserved = today.filter { $0.isDone }
        let picks = ExerciseCatalog.recommended(for: patterns)
        var unique: [String: ExerciseItem] = [:]
        for ex in picks { if unique[ex.name] == nil { unique[ex.name] = ex } }
        let planned = unique.values.map { PlannedExercise(exercise: $0, minutes: ExerciseCatalog.defaultMinutes(for: $0)) }
        today = preserved + planned
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(today)
            try data.write(to: url, options: [.atomic])
        } catch { /* swallow */ }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        if let items = try? JSONDecoder().decode([PlannedExercise].self, from: data) {
            today = items
        }
    }
}

