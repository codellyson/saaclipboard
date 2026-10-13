// Renders the 1024px app icon. Regenerate Support/AppIcon.icns with scripts/make-icon.sh.
import AppKit
import SwiftUI

struct Pin: View {
    var body: some View {
        let wood = Color(red: 0.82, green: 0.66, blue: 0.46)
        HStack(spacing: 4) { Capsule().fill(wood); Capsule().fill(wood.opacity(0.85)) }
            .frame(width: 34, height: 92)
            .overlay(Rectangle().fill(Color(white: 0.6)).frame(width: 42, height: 8).offset(y: -8))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
    }
}

struct Card<Content: View>: View {
    let angle: Double
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: -34) {
            Pin().zIndex(1)
            content
                .frame(width: 250, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(18)
                .background(.white, in: RoundedRectangle(cornerRadius: 36))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 14)
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }
}

struct Icon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.45, blue: 0.98), Color(red: 0.55, green: 0.78, blue: 1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 12)
            Path { p in
                p.move(to: CGPoint(x: 118, y: 330))
                p.addQuadCurve(to: CGPoint(x: 906, y: 330), control: CGPoint(x: 512, y: 450))
            }
            .stroke(Color(red: 0.55, green: 0.42, blue: 0.3), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 4)
            Card(angle: 6) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach([0.9, 0.65, 0.8], id: \.self) { w in
                        Capsule().fill(.black.opacity(0.55)).frame(width: 190 * w, height: 18)
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.pink.opacity(0.45))
            }
            .position(x: 330, y: 528)
            Card(angle: -5) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                    Circle().fill(.white.opacity(0.9)).frame(width: 60).offset(x: 60, y: -110)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 200)); p.addLine(to: CGPoint(x: 90, y: 90))
                        p.addLine(to: CGPoint(x: 150, y: 150)); p.addLine(to: CGPoint(x: 200, y: 110))
                        p.addLine(to: CGPoint(x: 250, y: 200)); p.closeSubpath()
                    }.fill(Color(red: 0.2, green: 0.5, blue: 0.35))
                }
            }
            .position(x: 694, y: 528)
        }
        .frame(width: 1024, height: 1024)
    }
}

MainActor.assumeIsolated {
    let r = ImageRenderer(content: Icon())
    r.scale = 1
    let rep = NSBitmapImageRep(cgImage: r.cgImage!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
