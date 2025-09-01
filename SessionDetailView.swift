import SwiftUI

struct SessionDetailView: View {
    let session: SessionSummary

    // Share sheet
    @State private var isSharing = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session Detail")
                    .font(.title.bold())

                group("Overview") {
                    row("Date", longDate(session.date))
                    row("Steps", "\(session.steps)")
                    row("Cadence", String(format: "%.0f spm", session.cadenceSPM))
                    row("Symmetry score", "\(session.symmetryScore)/100")
                }

                group("Timing") {
                    row("Avg step time", String(format: "%.2f s", session.avgStepTime))
                    row("Step time CV", String(format: "%.1f%%", session.cvStepTime * 100))
                    row("Step-time asymmetry", String(format: "%.1f%%", session.asymStepTimePct))
                }

                group("Stability") {
                    row("M/L sway (RMS)", String(format: "%.3f g", session.mlSwayRMS))
                }

                if !session.tags.isEmpty {
                    group("Auto Tags") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(session.tags, id: \.self) { t in
                                Label(t, systemImage: "exclamationmark.circle")
                            }
                        }
                    }
                }

                Button {
                    exportPDFAndShare()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(activityItems: shareItems)
        }
    }

    // MARK: - UI helpers

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(.vertical, 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.subheadline.monospacedDigit())
    }

    // MARK: - Sharing

    private func exportPDFAndShare() {
        // Unwrap current baseline (SessionPDFView expects a non-optional Baseline)
        guard let baseline = BaselineStore.shared.baseline else { return }
        let settings = UserSettingsStore.shared
        guard let norms = Norms.cadenceByAge[settings.ageGroup] else { return }

        let filename = "Session_\(fileDate(session.date))"

        // Build the SwiftUI view we want to render into a PDF
        let pdfView = SessionPDFView(
            session: session,
            baseline: baseline,
            ageGroup: settings.ageGroup,
            norms: norms,
            patternSuggestion: nil // pass a suggestion if you have one
        )

        do {
            let url = try PDFExporter.render(view: pdfView, filename: filename)
            shareItems = [url]
            isSharing = true
        } catch {
            print("PDF export failed: \(error)")
        }
    }

    private func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    private func fileDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return f.string(from: d)
    }
}

// MARK: - ShareSheet helper

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

