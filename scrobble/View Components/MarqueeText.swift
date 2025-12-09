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
    var containerWidth: Double = 200
    var speed: Double = 30 // points per second
    var pauseDuration: Double = 2

    @State private var offset: Double = 0
    @State private var textWidth: Double = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { geo in
                Color.clear.onAppear { textWidth = geo.size.width }
            })
            .textRenderer(MarqueeRenderer(offset: offset, containerWidth: containerWidth))
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .onAppear(perform: startAnimation)
            .onDisappear(perform: stopAnimation)
            .onChange(of: text) { _, _ in
                // Restart animation when text changes
                stopAnimation()
                offset = 0
                // Small delay to allow textWidth to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        guard textWidth > containerWidth else { return } // no scroll needed

        let scrollDistance = textWidth - containerWidth + 20
        let scrollDuration = scrollDistance / speed

        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                // Reset to start
                offset = 0

                // Pause at start
                try? await Task.sleep(for: .seconds(pauseDuration))
                guard !Task.isCancelled else { break }

                // Scroll left
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -scrollDistance
                }

                // Wait for scroll animation to complete + pause at end
                try? await Task.sleep(for: .seconds(scrollDuration + pauseDuration))
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}





#Preview {
    MarqueeText(
        text: "Some Really Long Song Title That Needs to Scroll",
        font: .headline,
        containerWidth: 200
    )
}
