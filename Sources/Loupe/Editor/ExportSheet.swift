import LoupeCore
import SwiftUI

struct ExportSheet: View {
    let editor: EditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var quality = ExportQuality.hd

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch editor.exportState {
            case .idle:
                options
            case let .exporting(progress):
                exporting(progress)
            case let .finished(url):
                finished(url)
            case let .failed(message):
                failed(message)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(.surface)
        .animation(.snappy, value: editor.exportState)
        .onDisappear { editor.exportState = .idle }
    }

    private var options: some View {
        Group {
            header("Export Video", subtitle: "MP4 with your zooms, camera and background baked in.")
            HStack(spacing: 10) {
                ForEach(ExportQuality.allCases) { option in
                    Button { quality = option } label: {
                        VStack(spacing: 4) {
                            Text(option.name)
                                .font(.heading)
                                .foregroundStyle(.primaryText)
                            Text(verbatim: "\(option.rawValue) wide")
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(quality == option ? 0.08 : 0.03), in: .rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(quality == option ? .brand : .hairline, lineWidth: quality == option ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.quiet)
                    .keyboardShortcut(.cancelAction)
                Button("Export") { Task { await editor.export(quality: quality) } }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func exporting(_ progress: Double) -> some View {
        Group {
            header("Exporting…", subtitle: "Rendering zooms, camera and background.")
            ProgressView(value: progress)
                .tint(.brand)
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.timecode)
                .foregroundStyle(.secondaryText)
        }
    }

    private func finished(_ url: URL) -> some View {
        Group {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                header("Ready to share", subtitle: url.lastPathComponent)
            }
            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([url as NSURL])
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.quiet)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.quiet)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func failed(_ message: String) -> some View {
        Group {
            header("Export failed", subtitle: message)
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.quiet)
                Button("Try Again") { editor.exportState = .idle }
                    .buttonStyle(.primary)
            }
        }
    }

    private func header(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primaryText)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondaryText)
                .lineLimit(2)
        }
    }
}
