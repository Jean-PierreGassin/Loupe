import SwiftUI

struct TitleField: View {
    @Binding var title: String
    @State private var original = ""
    @State private var editing = false
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if editing {
                TextField("Untitled", text: $title)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onAppear { focused = true }
                    .onSubmit { focused = false }
                    .onExitCommand { title = original; focused = false }
            } else {
                Button { begin() } label: {
                    HStack(spacing: 6) {
                        Text(title.isEmpty ? "Untitled" : title)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiaryText)
                            .opacity(hovering ? 1 : 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Rename")
                .onHover { hovering = $0 }
            }
        }
        .font(.heading)
        .foregroundStyle(.primaryText)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.white.opacity(editing ? 0.07 : hovering ? 0.04 : 0), in: .rect(cornerRadius: 7))
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .onDisappear(perform: commit)
    }

    private func begin() {
        original = title
        editing = true
    }

    private func commit() {
        guard editing else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        title = trimmed.isEmpty ? original : trimmed
        editing = false
    }
}
