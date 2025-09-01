import SwiftUI
import UIKit

enum PDFExporter {
    /// Renders any SwiftUI view into a single-page PDF and returns the file URL.
    /// The PDF is written to the temporary directory with the given `filename` (”.pdf” appended).
    static func render<V: View>(view: V, filename: String) throws -> URL {
        // Where to write
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("pdf")

        // Host the SwiftUI view in a UIView for rendering
        let hosting = UIHostingController(rootView: view)
        // Letter page size (points). Adjust if you prefer A4, etc.
        let pageSize = CGSize(width: 612, height: 792)
        hosting.view.frame = CGRect(origin: .zero, size: pageSize)

        // Prepare a PDF renderer
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        // Produce PDF data
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }

        try data.write(to: url, options: .atomic)
        return url
    }
}

