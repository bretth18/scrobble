//
//  MarqueeText.swift
//  scrobble
//
//  Created by Brett Henderson on 12/9/25.
//

import SwiftUI

struct MarqueeRenderer: TextRenderer {
    var offset: Double
    var containerWidth: Double
    var fadeWidth: Double = 20

    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let textWidth = layout.first?.typographicBounds.width ?? 0

        // Edge fade masks
        let leftFade = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.clear, .white]),
            startPoint: .zero,
            endPoint: CGPoint(x: fadeWidth, y: 0)
        )
        let rightFade = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.white, .clear]),
            startPoint: CGPoint(x: containerWidth - fadeWidth, y: 0),
            endPoint: CGPoint(x: containerWidth, y: 0)
        )

        context.clipToLayer { ctx in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: containerWidth, height: 1000)), with: .color(.white))

            // Apply fades only when text is scrolling past edges
            if offset < 0 {
                ctx.fill(Path(CGRect(x: 0, y: 0, width: fadeWidth, height: 1000)), with: leftFade)
            }
            if offset + textWidth > containerWidth {
                ctx.fill(Path(CGRect(x: containerWidth - fadeWidth, y: 0, width: fadeWidth, height: 1000)), with: rightFade)
            }
        }

        for line in layout {
            for run in line {
                for glyph in run {
                    var copy = context
                    copy.translateBy(x: offset, y: 0)
                    copy.draw(glyph, options: .disablesSubpixelQuantization)
                }
            }
        }
    }
}

struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var speed: Double = 30 // points per second
    var pauseDuration: Double = 1.5

    @State private var offset: Double = 0
    @State private var textWidth: Double = 0
    @State private var containerWidth: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var isHovering = false

    private var needsScrolling: Bool {
        containerWidth > 0 && textWidth > containerWidth
    }

    var body: some View {
        // Hidden text reserves the correct line height in layout,
        // truncated so it never pushes the container wider.
        Text(text)
            .font(font)
            .lineLimit(1)
            .truncationMode(.tail)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                GeometryReader { geo in
                    // Actual marquee text, rendered in an overlay so
                    // .fixedSize() can't influence the parent's width.
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize()
                        .background(GeometryReader { textGeo in
                            Color.clear
                                .onAppear { textWidth = textGeo.size.width }
                                .onChange(of: text) { textWidth = textGeo.size.width }
                        })
                        .textRenderer(MarqueeRenderer(offset: offset, containerWidth: geo.size.width))
                        .frame(width: geo.size.width, alignment: .leading)
                        .clipped()
                        .onAppear { containerWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in containerWidth = w }
                }
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering && needsScrolling {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
            .onDisappear {
                stopAnimation()
            }
    }

    private func startAnimation() {
        animationTask?.cancel()

        guard needsScrolling else { return }

        let scrollDistance = textWidth - containerWidth + 20
        let scrollDuration = scrollDistance / speed

        animationTask = Task { @MainActor in
            while !Task.isCancelled && isHovering {
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = 0
                }

                try? await Task.sleep(for: .seconds(pauseDuration))
                guard !Task.isCancelled && isHovering else { break }

                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -scrollDistance
                }

                try? await Task.sleep(for: .seconds(scrollDuration + pauseDuration))
            }

            if !isHovering {
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = 0
                }
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MarqueeText(
            text: "Short text",
            font: .body
        )
        MarqueeText(
            text: "Some Really Long Song Title That Definitely Needs to Scroll On Hover",
            font: .headline
        )
        Text("Regular text below for spacing comparison")
            .font(.body)
    }
    .frame(width: 250)
    .padding()
}
