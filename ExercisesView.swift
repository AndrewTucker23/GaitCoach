import SwiftUI

struct ExercisesView: View {
    @State private var selectedMuscle: MuscleGroup? = nil

    private var filtered: [ExerciseItem] {
        selectedMuscle.map { ExerciseCatalog.byMuscle($0) } ?? ExerciseCatalog.exercises
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Muscle", selection: $selectedMuscle) {
                        Text("All").tag(nil as MuscleGroup?)
                        ForEach(MuscleGroup.allCases, id: \.self) { m in
                            Text(m.uiName)                // or m.displayName if that’s what you use
                                .tag(Optional(m))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Exercises") {
                    ForEach(filtered) { item in
                        NavigationLink {
                            ExerciseDetailView(item: item) // <- video + timer screen
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.systemImage).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.headline)
                                    Text(item.blurb)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Text(item.durationLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(item.muscleListLabel) // or join names yourself
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
        }
    }
}

#Preview { ExercisesView() }

