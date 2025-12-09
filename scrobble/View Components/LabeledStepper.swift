//
//  LabeledStepper.swift
//  scrobble
//
//  Created by Brett Henderson on 12/9/25.
//

import SwiftUI


struct LabeledStepper<V: Strideable>: View {
    let label: String
    @Binding var value: V
    let range: ClosedRange<V>
    let step: V.Stride
    let format: (V) -> String
    
    init(
        _ label: String,
        value: Binding<V>,
        in range: ClosedRange<V>,
        step: V.Stride,
        format: @escaping (V) -> String = { "\($0)" }
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(format(value))
                    .monospacedDigit()
                
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Convenience Initializers

extension LabeledStepper where V == Int {
    init(
        _ label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        format: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = 1
        self.format = format
    }
}

extension LabeledStepper where V == Double {
    init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String = { String(format: "%.1f", $0) }
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }
}

// MARK: - Previews

#Preview("Basic Usage") {
    @Previewable @State var friendsShown = 3
    @Previewable @State var recentTracks = 5
    
    Form {
        Section("Display") {
            LabeledStepper("Friends shown", value: $friendsShown, in: 1...10)
            LabeledStepper("Friend recent tracks", value: $recentTracks, in: 1...20)
        }
    }
    .formStyle(.grouped)
    .frame(width: 400)
}

#Preview("Custom Formatting") {
    @Previewable @State var volume = 75
    @Previewable @State var brightness = 0.8
    
    Form {
        Section("Audio") {
            LabeledStepper("Volume", value: $volume, in: 0...100) { "\($0)%" }
        }
        
        Section("Display") {
            LabeledStepper("Brightness", value: $brightness, in: 0.0...1.0, step: 0.1) {
                "\(Int($0 * 100))%"
            }
        }
    }
    .formStyle(.grouped)
    .frame(width: 400)
}

#Preview("Dark Mode") {
    @Previewable @State var count = 5
    
    Form {
        Section("Settings") {
            LabeledStepper("Item count", value: $count, in: 1...20)
        }
    }
    .formStyle(.grouped)
    .frame(width: 400)
    .preferredColorScheme(.dark)
}
