import Foundation
import CoreGraphics

// Generate the README diagram with the same geometry used by the app.
let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
var settings = LayoutSettings()
settings.centerWidth = Dimension(60)
settings.alternateLeft.enabled = true; settings.alternateLeft.width = Dimension(20)
settings.alternateRight.enabled = true; settings.alternateRight.width = Dimension(20)
let center = Layout.frame(for: .center, current: .zero, screen: screen, settings: settings)
let left = Layout.frame(for: .left, current: .zero, screen: screen, settings: settings)
let alternateLeft = Layout.frame(for: .left, current: left, screen: screen, settings: settings)
let right = Layout.frame(for: .right, current: .zero, screen: screen, settings: settings)
let alternateRight = Layout.frame(for: .right, current: right, screen: screen, settings: settings)
func number(_ value: CGFloat) -> String { String(format: "%.2f", Double(value)) }
func pane(_ rect: CGRect, color: String, offset: CGFloat, label: String = "") -> String {
    let scale: CGFloat = 0.14
    let x = offset + rect.minX * scale, y = 76 + rect.minY * scale
    let width = rect.width * scale, height = rect.height * scale
    return """
    <rect x="\(number(x))" y="\(number(y))" width="\(number(width))" height="\(number(height))" rx="5" fill="\(color)" stroke="#fff" stroke-width="2"/>
    <path d="M\(number(x + 6)) \(number(y + 19)) H\(number(x + width - 6))" stroke="#fff" opacity=".35"/>
    <text x="\(number(x + width / 2))" y="\(number(y + height / 2 + 8))" text-anchor="middle" fill="#fff" font-size="17" font-weight="600">\(label)</text>
    """
}
var body = ""
for index in 0..<3 {
    let x = CGFloat(26 + index * 320)
    let title = ["1. Left", "2. Left again", "3. Repeat on Right"][index]
    let caption = ["Normal split", "Configured alternate width", "Room for your main window"][index]
    body += """
    <text x="\(number(x))" y="49" font-size="21" font-weight="650" fill="#17243b">\(title)</text>
    <rect x="\(number(x))" y="76" width="280" height="140" rx="7" fill="#e5eaf2"/>
    """
    body += pane(center, color: "#456ed2", offset: x, label: index == 0 ? "" : "60%")
    body += pane(index == 0 ? left : alternateLeft, color: "#087f8c", offset: x, label: index == 0 ? "50%" : "20%")
    if index == 2 { body += pane(alternateRight, color: "#7450b5", offset: x, label: "20%") }
    body += "<text x=\"\(number(x))\" y=\"246\" font-size=\"16\" fill=\"#42526a\">\(caption)</text>"
}
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="972" height="308" viewBox="0 0 972 308" role="img" aria-labelledby="title description">
<title id="title">Repeated Left and Right make room around a centered window</title>
<desc id="description">Example: Center is 60 percent wide. Left first uses a 50 percent split, then a 20 percent side pane. Repeating Right creates the matching side. Every width is configurable.</desc>
<rect width="972" height="308" rx="16" fill="#f5f7fb"/>
<g font-family="-apple-system, BlinkMacSystemFont, Arial, sans-serif">\(body)
<text x="486" y="285" text-anchor="middle" font-size="15" fill="#42526a">Example values only. Configure Center and side widths in percent or points.</text></g>
</svg>
"""
let output = CommandLine.arguments.dropFirst().first ?? "docs/images/window-layout.svg"
try svg.write(toFile: output, atomically: true, encoding: .utf8)
