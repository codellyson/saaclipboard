import AppKit
import SwiftUI

struct Clip: Identifiable, Equatable {
    let id = UUID()
    var text = ""
    var image: NSImage?
    let tint: Color
}

@MainActor
final class Clipboard: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var shown = false
    var onHang: (() -> Void)?
    private var lastCount = NSPasteboard.general.changeCount
    private let tints: [Color] = [.pink, .orange, .yellow, .mint, .teal, .indigo, .purple]
    private var timer: Timer?

    // shortcut: polls changeCount (macOS has no clipboard-change notification); text and images only
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { self.check() }
        }
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount
        let tint = tints.randomElement()!
        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            guard text != clips.first?.text else { return }
            hang(Clip(text: text, tint: tint))
        } else if let image = NSImage(pasteboard: pb) {
            hang(Clip(image: image, tint: tint))
        }
    }

    private func hang(_ clip: Clip) {
        onHang?()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
            if !clip.text.isEmpty { clips.removeAll { $0.text == clip.text } }
            clips.insert(clip, at: 0)
            clips = Array(clips.prefix(8))
        }
    }

    func copy(_ clip: Clip) {
        NSPasteboard.general.clearContents()
        if let image = clip.image {
            NSPasteboard.general.writeObjects([image])
        } else {
            NSPasteboard.general.setString(clip.text, forType: .string)
        }
        lastCount = NSPasteboard.general.changeCount
        pasteIntoFocusedApp()
    }

    /// Panel is non-activating, so the user's app keeps focus; send it cmd+V.
    private func pasteIntoFocusedApp() {
        // posting key events needs Accessibility permission; this prompts once
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down) // 9 = V
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
    }

    func remove(_ clip: Clip) {
        withAnimation { clips.removeAll { $0 == clip } }
    }
}

struct LineView: View {
    @ObservedObject var board: Clipboard
    let ropeY: CGFloat = 18
    let sag: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // rope is a quadratic curve; y(x) gives where each pin sits on it
            let ropeAt = { (x: CGFloat) -> CGFloat in
                let t = x / w
                return ropeY + 4 * sag * t * (1 - t)
            }
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: ropeY))
                    p.addQuadCurve(to: CGPoint(x: w, y: ropeY), control: CGPoint(x: w / 2, y: ropeY + 2 * sag))
                }
                .stroke(Color(red: 0.62, green: 0.5, blue: 0.36), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .overlay {
                    // twist marks make it read as twine
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: ropeY))
                        p.addQuadCurve(to: CGPoint(x: w, y: ropeY), control: CGPoint(x: w / 2, y: ropeY + 2 * sag))
                    }
                    .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), style: StrokeStyle(lineWidth: 3, dash: [2, 4]))
                }
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)

                ForEach(Array(board.clips.enumerated()), id: \.element.id) { i, clip in
                    let x = w * CGFloat(i + 1) / CGFloat(board.clips.count + 1)
                    Garment(clip: clip, phase: Double(i)) { board.copy(clip) }
                        .position(x: x, y: ropeAt(x) + Garment.height / 2 - 8) // pin top bites over rope
                        .contextMenu { Button("Take down") { board.remove(clip) } }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .offset(y: board.shown ? 0 : -60)
        .opacity(board.shown ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: board.shown)
    }
}

struct Garment: View {
    static let height: CGFloat = 22 + 80 - 8
    let clip: Clip
    let phase: Double
    let onCopy: () -> Void
    @State private var copied = false
    @State private var born = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            // big swing when first pegged, settling into a gentle breeze
            let kick = 10 * exp(-(t - born.timeIntervalSinceReferenceDate) * 1.2)
            let sway = sin(t * 1.4 + phase) * (2 + kick) + sin(t * 0.6 + phase * 2)
            VStack(spacing: -8) {
                Clothespin().zIndex(1)
                Group {
                    if let image = clip.image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(clip.text)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .lineLimit(5)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.black.opacity(0.75))
                            .padding(7)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(clip.tint.opacity(0.35))
                    }
                }
                .frame(width: 102, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(5)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        if copied { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, .green).padding(8) }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 4, x: CGFloat(sway), y: 3)
            }
            .rotationEffect(.degrees(sway), anchor: .top)
        }
        .help(clip.image == nil ? clip.text : "Image")
        .onTapGesture {
            onCopy()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
        }
    }
}

struct Clothespin: View {
    var body: some View {
        let wood = Color(red: 0.82, green: 0.66, blue: 0.46)
        HStack(spacing: 1) {
            Capsule().fill(wood)
            Capsule().fill(wood.opacity(0.85))
        }
        .frame(width: 9, height: 22)
        .overlay(Rectangle().fill(.gray.gradient).frame(width: 11, height: 2).offset(y: -2))
        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
    }
}
