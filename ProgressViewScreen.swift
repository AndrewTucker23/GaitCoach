import SwiftUI

struct ProgressViewScreen: View {
    @StateObject private var sessionStore = SessionSummaryStore.shared
    @State private var isSharing = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Progress").font(.title.bold())

                weeklySummaryCard

                // Latest session preview (unchanged shape)
                if let last = sessionStore.sessions.last {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last session").font(.headline)
                        HStack {
                            Text(longDate(last.date))
                            Spacer()
                            Text("\(last.symmetryScore)/100")
                                .font(.callout.monospacedDigit())
                        }
                        .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        gridRow("Steps", "\(last.steps)")
                        gridRow("Cadence", String(format: "%.0f spm", last.cadenceSPM))
                        gridRow("Avg step time", String(format: "%.2f s", last.avgStepTime))
                        gridRow("Step time CV", String(format: "%.1f%%", last.cvStepTime * 100))
                        gridRow("Step-time asymmetry", String(format: "%.1f%%", last.asymStepTimePct))
                        gridRow("M/L sway (RMS)", String(format: "%.3f g", last.mlSwayRMS))
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("No sessions yet — start a Walk to record one.")
                        .foregroundStyle(.secondary)
                }

                // Recent history
                if !sessionStore.sessions.isEmpty {
                    Text("Recent Sessions").font(.headline).padding(.top, 8)
                    ForEach(Array(sessionStore.sessions.suffix(10).reversed())) { s in
                        HStack {
                            Text(shortDate(s.date))
                            Spacer()
                            Text("\(s.symmetryScore)")
                                .font(.callout.monospacedDigit())
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        Divider()
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Weekly summary

    private var weeklySummaryCard: some View {
        let week = last7()
        return VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Summary").font(.headline)
            if week.isEmpty {
                Text("No walks in the last 7 days.")
                    .foregroundStyle(.secondary)
            } else {
                let avgScore = Int(week.map(\.symmetryScore).reduce(0, +) / max(1, week.count))
                let avgCad = week.map(\.cadenceSPM).reduce(0, +) / Double(week.count)
                let avgML  = week.map(\.mlSwayRMS).reduce(0, +) / Double(week.count)
                HStack {
                    Text("Avg symmetry score: \(avgScore)/100")
                    Spacer()
                    Text(String(format: "Avg cadence: %.0f spm", avgCad))
                    Spacer()
                    Text(String(format: "Avg sway: %.3f g", avgML))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button {
                    exportWeeklyPDF(week)
                } label: {
                    Label("Export Weekly PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func last7() -> [SessionSummary] {
        let cut = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessionStore.sessions.filter { $0.date >= cut }
    }

    private func exportWeeklyPDF(_ week: [SessionSummary]) {
        let view = WeeklyPDFView(week: week)
        let name = "Weekly_\(fileDate(Date()))"
        do {
            let url = try PDFExporter.render(view: view, filename: name)
            shareItems = [url]
            isSharing = true
        } catch { print("Weekly PDF failed: \(error)") }
    }

    // MARK: - Helpers

    private func gridRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
            .font(.subheadline.monospacedDigit())
    }
    private func shortDate(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: d) }
    private func longDate(_ d: Date) -> String { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: d) }
    private func fileDate(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d) }
}

// Minimal share sheet
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// PDF view for weekly export
private struct WeeklyPDFView: View {
    let week: [SessionSummary]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Report").font(.title.bold())
            ForEach(week) { s in
                HStack {
                    Text(dateString(s.date))
                    Spacer()
                    Text("Score \(s.symmetryScore)")
                    Spacer()
                    Text(String(format: "%.0f spm", s.cadenceSPM))
                    Spacer()
                    Text(String(format: "%.3f g", s.mlSwayRMS))
                }
                .font(.subheadline.monospacedDigit())
            }
        }
        .padding()
    }
    private func dateString(_ d: Date) -> String { let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d) }
}

