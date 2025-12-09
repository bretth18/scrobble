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
    }
    
    private func startAnimation() {
        guard textWidth > containerWidth else { return } // no scroll needed
        
        let scrollDistance = textWidth - containerWidth + 20
        let scrollDuration = scrollDistance / speed
        
        func cycle() {
            offset = 0
            
            // Pause at start
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                // Scroll left
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -scrollDistance
                }
                
                // Pause at end, then restart
                DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + pauseDuration) {
                    cycle()
                }
            }
        }
        
        cycle()
    }
}





#Preview {
    MarqueeText(
        text: "Some Really Long Song Title That Needs to Scroll",
        font: .headline,
        containerWidth: 200
    )
}
