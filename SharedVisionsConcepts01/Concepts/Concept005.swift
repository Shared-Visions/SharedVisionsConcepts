//  Step Into Vision - Example Code
//
//  Title: Concept005
//
//  Subtitle: Horizontal Scroll
//
//  Description: A simple horizontally scrolling list of placeholder items in a window.
//
//  Type: Window Alt
//
//  Featured: false
//
//  Created by Joseph Simpson on 2/9/26.

import SwiftUI

struct Concept005: View {
    private let itemCount = 20
    @State private var showDebug = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Horizontal Scroll with linear gradient mask")
                .padding()
                .glassBackgroundEffect(in: .capsule, displayMode: .always)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(0..<itemCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.black)
                            .frame(width: 200, height: 200)
                            .debugBorder3D(showDebug ? .white : .clear)
                    }
                }
                .padding(.horizontal, 40)
            }
            .mask {
                LinearGradient(gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)

                ]), startPoint: .leading, endPoint: .trailing)
            }

            Toggle(isOn: $showDebug, label: {
                Text("Debug Lines")
            })
            .toggleStyle(.button)
            .padding()
            .glassBackgroundEffect(in: .capsule, displayMode: .always)
        }
        .frame(width: 800, height: 400)
        .padding()
    }
}



#Preview {
    Concept005()
}
