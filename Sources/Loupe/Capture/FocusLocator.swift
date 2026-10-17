import AppKit
import ApplicationServices

enum FocusLocator {
    private static let largestFieldShare = 0.35

    static func textFocus() -> CGPoint? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        guard let element = system.element(kAXFocusedUIElementAttribute) else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.05)
        if let caret = element.caretBounds {
            return CGPoint(x: caret.minX, y: caret.midY)
        }
        guard let frame = element.frame, let screen = NSScreen.screens.first?.frame else { return nil }
        let share = (frame.width * frame.height) / (screen.width * screen.height)
        return share < largestFieldShare ? CGPoint(x: frame.midX, y: frame.midY) : nil
    }

    static func exposeAccessibility(of pid: pid_t) -> Bool {
        let app = application(pid)
        guard (app.copy(manualAccessibility) as? Bool) != true else { return false }
        return AXUIElementSetAttributeValue(app, manualAccessibility as CFString, kCFBooleanTrue) == .success
    }

    static func restoreAccessibility(of pid: pid_t) {
        AXUIElementSetAttributeValue(application(pid), manualAccessibility as CFString, kCFBooleanFalse)
    }

    private static let manualAccessibility = "AXManualAccessibility"

    private static func application(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        return app
    }
}

private extension AXUIElement {
    func copy(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success ? value : nil
    }

    func element(_ attribute: String) -> AXUIElement? {
        guard let value = copy(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    func axValue<T: BitwiseCopyable>(_ attribute: String, as type: AXValueType, default empty: T) -> T? {
        copy(attribute).flatMap { AXValue.unwrap($0, as: type, default: empty) }
    }

    var frame: CGRect? {
        guard
            let origin = axValue(kAXPositionAttribute, as: .cgPoint, default: CGPoint.zero),
            let size = axValue(kAXSizeAttribute, as: .cgSize, default: CGSize.zero),
            size.width > 0, size.height > 0
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    var caretBounds: CGRect? {
        guard let selection = axValue(kAXSelectedTextRangeAttribute, as: .cfRange, default: CFRange()) else { return nil }
        let candidates = [selection, CFRange(location: selection.location, length: 1), CFRange(location: max(0, selection.location - 1), length: 1)]
        return candidates.lazy.compactMap(bounds(for:)).first
    }

    private func bounds(for range: CFRange) -> CGRect? {
        var range = range
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(self, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &value) == .success,
            let value,
            let rect = AXValue.unwrap(value, as: .cgRect, default: CGRect.zero),
            rect.height > 0, rect.height < 400
        else { return nil }
        return rect
    }
}

private extension AXValue {
    static func unwrap<T: BitwiseCopyable>(_ object: AnyObject, as type: AXValueType, default empty: T) -> T? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var result = empty
        return AXValueGetValue(object as! AXValue, type, &result) ? result : nil
    }
}
