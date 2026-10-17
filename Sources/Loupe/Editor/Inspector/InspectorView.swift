import LoupeCore
import SwiftUI

struct InspectorView: View {
    @Bindable var editor: EditorModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let zoom = editor.selectedZoom {
                    InspectorSection("Selected Zoom") {
                        LabeledSlider("Depth", value: zoomScale(zoom), in: 1.25...4, format: "%.1f×")
                        Button(role: .destructive, action: editor.deleteSelectedZoom) {
                            Label("Remove Zoom", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.quiet)
                    }
                }

                InspectorSection("Background") {
                    BackgroundPicker(selection: $editor.project.style.background)
                }

                InspectorSection("Frame") {
                    LabeledSlider("Padding", value: $editor.project.style.padding, in: 0.02...0.14, format: percent)
                    LabeledSlider("Roundness", value: $editor.project.style.cornerRadius, in: 0...0.05, format: percent)
                    InspectorToggle("Shadow", isOn: $editor.project.style.shadow)
                }
                .disabled(!editor.project.style.hasBackground)

                if editor.project.hasCamera {
                    InspectorSection("Camera") {
                        InspectorToggle("Show camera", isOn: $editor.project.style.camera.visible)
                        Group {
                            Picker("Shape", selection: $editor.project.style.camera.shape) {
                                Text("Circle").tag(CameraStyle.Shape.circle)
                                Text("Rounded").tag(CameraStyle.Shape.rounded)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            LabeledSlider("Size", value: cameraSize, in: 0.12...0.4, format: percent)
                            CornerPicker(camera: $editor.project.style.camera, aspect: editor.project.aspect)
                            InspectorToggle("Mirror", isOn: $editor.project.style.camera.mirror)
                        }
                        .disabled(!editor.project.style.camera.visible)
                    }
                }

                InspectorSection("Zoom") {
                    InspectorToggle("Auto zoom on clicks and typing", isOn: Binding(get: { editor.project.autoZoom }, set: editor.setAutoZoom))
                    LabeledSlider("Default depth", value: Binding(get: { editor.project.defaultZoomScale }, set: editor.setDefaultZoomScale), in: 1.25...3.5, format: "%.1f×")
                    Text(zoomSummary)
                        .font(.caption)
                        .foregroundStyle(.tertiaryText)
                }

                InspectorSection("Cursor") {
                    InspectorToggle("Highlight clicks", isOn: $editor.project.style.clickHighlights)
                }
            }
            .padding(.top, 40)
        }
        .scrollIndicators(.never)
        .tint(.brand)
        .controlSize(.small)
    }

    private let percent = "%.0f%%"

    private var zoomSummary: String {
        let count = editor.project.zooms.count
        let clicks = editor.project.events.count { $0.kind == .click }
        return "\(count) zoom\(count == 1 ? "" : "s") · \(clicks) click\(clicks == 1 ? "" : "s") captured"
    }

    private var cameraSize: Binding<Double> {
        Binding(
            get: { editor.project.style.camera.size },
            set: { size in
                editor.project.style.camera.size = size
                editor.project.style.camera.center = editor.project.style.camera.clamped(editor.project.style.camera.center, aspect: editor.project.aspect)
            }
        )
    }

    private func zoomScale(_ zoom: ZoomSegment) -> Binding<Double> {
        Binding(get: { zoom.scale }, set: { editor.setZoomScale(zoom.id, $0) })
    }
}
