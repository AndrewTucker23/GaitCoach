import SwiftUI

struct CitationsView: View {
    var body: some View {
        List {
            Section("Why we compare cadence to age-matched targets") {
                Text("CADENCE-Adults provides evidence-based cadence thresholds that map to MET intensities. We surface these as age-matched targets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinkRow(title: "Adults 21–40 & 41–60: Moderate ≈100 spm, Vigorous ≈130 spm (IJBNPA)",
                        url: "https://ijbnpa.biomedcentral.com/articles/10.1186/s12966-019-0769-6",
                        systemImage: "link")

                LinkRow(title: "Follow-on thresholds for middle-aged adults (IJBNPA)",
                        url: "https://ijbnpa.biomedcentral.com/articles/10.1186/s12966-020-01045-z",
                        systemImage: "link")

                LinkRow(title: "Older adults 61–85: Moderate ~100–105 spm; 4/5 METs at 110/120 spm",
                        url: "https://health.oregonstate.edu/research/publications/101186s12966-023-01543-w-0",
                        systemImage: "link")
            }

            Section("Why track variability and M/L sway vs your own baseline") {
                Text("Temporal variability and mediolateral trunk acceleration relate to stability and fall risk, but absolute values depend on speed and sensor placement—so baseline-relative tracking is safest.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinkRow(title: "Trunk accelerometry for gait stability/fall risk (review)",
                        url: "https://doi.org/10.1155/2016/1938686",
                        systemImage: "link")

                LinkRow(title: "Variability measures in gait: clinical significance",
                        url: "https://doi.org/10.1007/s11517-010-0641-7",
                        systemImage: "link")
            }

            Section("Symmetry & rehab relevance") {
                Text("Asymmetry (step time/length) relates to energy cost and function; useful for coaching even without lab gear.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinkRow(title: "Gait symmetry & composite scores (GSI concept)",
                        url: "https://doi.org/10.1016/j.gaitpost.2014.09.013",
                        systemImage: "link")

                LinkRow(title: "Step-length asymmetry and energy cost (post-stroke example)",
                        url: "https://doi.org/10.1007/s00421-013-2749-2",
                        systemImage: "link")
            }

            Section("Notes") {
                Text("This app provides monitoring and coaching only. It does not diagnose disease or replace clinical care.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Citations & Rationale")
    }
}

private struct LinkRow: View {
    let title: String
    let url: String
    let systemImage: String

    var body: some View {
        if let link = URL(string: url) {
            Link(destination: link) {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
            }
        } else {
            // Fallback if URL ever mis-typed
            Label(title, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview { CitationsView() }

