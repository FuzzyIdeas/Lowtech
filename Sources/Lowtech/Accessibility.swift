import Cocoa
import SwiftUI

public extension NSWindow {
    /// Takes a window that only paints (overlays, passive OSDs, anchors) out of the app's
    /// `AXWindows` list. The popover role with an unknown subrole kept window managers off these
    /// but still listed them, often first, so VoiceOver and computer-use agents picked an
    /// invisible window for the app's front window.
    func hideFromAccessibility() {
        setAccessibilityElement(false)
    }
}

public extension View {
    /// Stands a native slider in for a drag-gesture track in the accessibility tree. A gesture is
    /// invisible to VoiceOver and to computer-use agents; the stand-in is an AXSlider they can read,
    /// step and set. `position` is the track's own 0...1 axis. `value` overrides the spoken value
    /// when the percent of the track is not the number on screen.
    ///
    /// The value goes outside the representation: set inside it, SwiftUI drops it.
    @ViewBuilder func accessibilitySlider(_ label: String, position: Binding<Double>, value: String? = nil, disabled: Bool = false) -> some View {
        let represented = accessibilityRepresentation {
            SwiftUI.Slider(value: position, in: 0 ... 1) { Text(label) }
                .disabled(disabled)
        }
        if let value {
            represented.accessibilityValue(value)
        } else {
            represented
        }
    }

    /// For a view that acts through `.onTapGesture`. A tap gesture is invisible to accessibility:
    /// VoiceOver reads the view as static text and an AXPress does nothing. This folds the view
    /// into one button element that runs `action` on press.
    func accessibleTap(_ label: String? = nil, selected: Bool? = nil, action: @escaping () -> Void) -> some View {
        accessibilityElement(children: .combine)
            .modifier(OptionalAccessibilityLabel(label: label))
            .accessibilityAddTraits(selected == true ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(.default, action)
    }

    /// For a row that acts through `.onTapGesture` but holds buttons of its own (delete, record a
    /// key), which `accessibleTap` would merge away. The row stays a group with its children and
    /// gains a press that runs `action`.
    func accessibilityPress(_ label: String? = nil, action: @escaping () -> Void) -> some View {
        accessibilityElement(children: .contain)
            .modifier(OptionalAccessibilityLabel(label: label))
            .accessibilityAction(.default, action)
    }

    /// For a Button drawn as an on/off pill or chip. Without it the pill reads as a plain button
    /// and nothing tells VoiceOver or an agent whether it is on.
    @ViewBuilder func accessibilityToggle(isOn: Bool) -> some View {
        if #available(macOS 14.0, *) {
            accessibilityAddTraits(isOn ? [.isToggle, .isSelected] : .isToggle)
        } else {
            accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

private struct OptionalAccessibilityLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}
