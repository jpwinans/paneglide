import SwiftUI
import PaneGlideCore

/// A labeled example, independent of the user's saved layout.
struct LayoutDemo: View {
    private let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    private var example: LayoutSettings {
        var value = LayoutSettings()
        value.centerWidth = Dimension(60)
        value.alternateLeft.enabled = true; value.alternateLeft.width = Dimension(20)
        value.alternateRight.enabled = true; value.alternateRight.width = Dimension(20)
        return value
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                panel("Left", alternate: false, right: false)
                panel("Left again", alternate: true, right: false)
                panel("Repeat on Right", alternate: true, right: true)
            }
            Text("Example: Center 60%, sides 20%. Choose your own widths in percent or points, or use Fit beside Center.")
                .font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("Example with a 60 percent Center: Left first fills the normal half, Left again uses a 20 percent side pane. Repeating on Right fills the other side. All widths are configurable.")
    }
    private func panel(_ title: String, alternate: Bool, right: Bool) -> some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let scale = proxy.size.width / screen.width
                let normal = Layout.frame(for: .left, current: .zero, screen: screen, settings: example)
                let left = alternate ? Layout.frame(for: .left, current: normal, screen: screen, settings: example) : normal
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 5).fill(.quaternary)
                    pane(Layout.frame(for: .center, current: .zero, screen: screen, settings: example), color: .blue.opacity(0.55), scale: scale)
                    pane(left, color: .teal, scale: scale)
                    if right {
                        let normalRight = Layout.frame(for: .right, current: .zero, screen: screen, settings: example)
                        pane(Layout.frame(for: .right, current: normalRight, screen: screen, settings: example), color: .purple, scale: scale)
                    }
                }
            }.aspectRatio(2, contentMode: .fit)
            Text(title).font(.caption).lineLimit(1)
        }
    }
    private func pane(_ frame: CGRect, color: Color, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.25), lineWidth: 1))
            .frame(width: frame.width * scale, height: frame.height * scale)
            .offset(x: frame.minX * scale, y: frame.minY * scale)
    }
}
