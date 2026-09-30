//
//  ConceptDetail.swift
//  SharedVisionsConcepts01
//
//  Created by Joseph Simpson on 2/1/26.
//

import SwiftUI

struct ConceptDetail: View {

    var concept: Concept

    // 2D Windows
    @Environment(\.openWindow) private var openWindow
    @Environment(\.pushWindow) private var pushWindow
    @Environment(\.dismissWindow) private var dismissWindow

    // Immersive Spaces
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    // Local state
    @State private var showConceptContent = false
    @State private var conceptIsOpen = false
    @State private var currentRoute: String?

    init(concept: Concept) {
        self.concept = concept
        _currentRoute = State(initialValue: concept.title)
    }

    var body: some View {
        List {
            Section() {
                VStack(alignment: .leading) {
                    Text("\(concept.title) - \(concept.subtitle)")
                        .font(.title)
                    Text("\(concept.date.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                }
                Text(.init(concept.description))
                if(concept.success == false) {
                    HStack {
                        Text("This concept was marked as a failure")
                        Spacer()
                        Image(systemName: "x.circle.fill")
                            .foregroundColor(.red)
                            .padding(4)
                    }
                }
            }

            Section() {

                HStack(alignment: .center, content: {
                    Text(concept.type.rawValue)
                    Spacer()
                    Toggle(isOn: $showConceptContent) {
                        Text(showConceptContent ? "Close Concept" : "Open Concept")
                    }
                    .toggleStyle(.button)
                })
                .padding(.vertical, 6)
            }
        }
        .listStyle(.grouped)
        .onChange(of: showConceptContent) { _, newValue in
            Task {
                if(concept.type == .WINDOW) {
                    handleWindow()
                } else if (concept.type == .WINDOW_ALT) {
                    handleWindowAlt()
                } else if (concept.type == .VOLUME) {
                    handleVolume()
                } else if (concept.type == .SPACE) {
                    await handleSpace(newValue: newValue)
                } else if (concept.type == .SPACE_FULL) {
                    await handleSpaceFull(newValue: newValue)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .conceptViewDidDisappear)) { notification in
            if notification.userInfo?["conceptTitle"] is String {
                // Reset the state when the concept view disappears
                showConceptContent = false
            }
        }
        .navigationTitle("Shared Visions")
    }

    func handleWindow() {
        if(conceptIsOpen) {
            dismissWindow(id: "RouterWindow")
            conceptIsOpen = false
            showConceptContent = false
        } else {
            pushWindow(id: "RouterWindow", value: concept.title)
            conceptIsOpen = true
        }
    }

    func handleWindowAlt() {
        if(conceptIsOpen) {
            dismissWindow(id: "RouterWindowAlt")
            conceptIsOpen = false
            showConceptContent = false
        } else {
            pushWindow(id: "RouterWindowAlt", value: concept.title)
            conceptIsOpen = true
        }
    }

    func handleVolume() {
        if(conceptIsOpen) {
            dismissWindow(id: "RouterVolume")
            conceptIsOpen = false
            showConceptContent = false
        } else {
            openWindow(id: "RouterVolume", value: concept.title)
            conceptIsOpen = true
        }
    }

    func handleSpace(newValue: Bool) async {
        if newValue {
            switch await openImmersiveSpace(id: "RouterSpace", value: concept.title) {
            case .opened:
                conceptIsOpen = true
                // Mixed-immersion spaces coexist with the main window (see
                // `.immersiveEnvironmentBehavior(.coexist)` in the app scene),
                // so leave it open — closing it here left users with no way
                // back to the concept list once inside.
            case .error, .userCancelled:
                fallthrough
            @unknown default:
                conceptIsOpen = false
                showConceptContent = false
            }
        } else {
            // Always ask the system to dismiss the mixed immersive space when
            // the toggle is turned off. This avoids a stale local-state flag
            // leaving Concept 12 (or any other mixed-space concept) visible.
            await dismissImmersiveSpace()
            conceptIsOpen = false
            showConceptContent = false
        }
    }

    func handleSpaceFull(newValue: Bool) async {
        if newValue {
            switch await openImmersiveSpace(id: "RouterSpaceFull", value: concept.title) {
            case .opened:
                conceptIsOpen = true
                // Full-immersion spaces replace the surroundings entirely and
                // the main window would float uselessly in front of them, so
                // hide it — the concept itself is responsible for providing
                // its own way back out (see Concept011's exit button).
                dismissWindow(id: "MainWindow")
            case .error, .userCancelled:
                fallthrough
            @unknown default:
                conceptIsOpen = false
                showConceptContent = false
            }
        } else if conceptIsOpen {
            await dismissImmersiveSpace()
            conceptIsOpen = false
            openWindow(id: "MainWindow")
        }
    }

}

#Preview {
    let modelData = ModelData()
    let length = modelData.conceptData.count
    if length > 0 {
        return ConceptDetail(concept: modelData.conceptData[length - 1])
    } else {
        return Text("No concepts available")
    }
}
