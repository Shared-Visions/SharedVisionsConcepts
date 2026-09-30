//
//  SharedVisionsConcepts01App.swift
//  SharedVisionsConcepts01
//
//  Created by Joseph Simpson on 2/1/26.
//

import SwiftUI

@main
struct SharedVisionsConcepts01App: App {
    @State private var appModel = AppModel()
    @State private var modelData = ModelData()
    @State private var conceptImmersionStyle: ImmersionStyle = .full

    var body: some Scene {

        // Main window
        WindowGroup(id: "MainWindow") {
            Directory()
                .environment(appModel)
                .environment(modelData)
        }
        .defaultSize(CGSize(width: 700, height: 640))

        // Router scenes

        // 1. Window: Use this window group to open 2D windows with Concept Content based on the Router
        WindowGroup(id: "RouterWindow", for: String.self, content: { $route in
            ConceptRouter(route: $route)
                .environment(appModel)
        })
        .windowResizability(.contentSize)
//        .defaultWindowPlacement { content, context in
//            let size = content.sizeThatFits(.unspecified)
//            if let mainWindow = context.windows.first {
//                return WindowPlacement(.trailing(mainWindow), size: size)
//            }
//            return WindowPlacement(.none)
//        }

        // 2. Window Alt: Use this window group to open plain 2D windows
        WindowGroup(id: "RouterWindowAlt", for: String.self, content: { $route in
            ConceptRouter(route: $route)
                .environment(appModel)
        })
        .windowStyle(.plain)
        .windowResizability(.contentSize)
//        .defaultWindowPlacement { content, context in
//            let size = content.sizeThatFits(.unspecified)
//            if let mainWindow = context.windows.first {
//                return WindowPlacement(.trailing(mainWindow), size: size)
//            }
//            return WindowPlacement(.none)
//        }

        // 3. Volume: Use this window group to open 3D Volumes
        WindowGroup(id: "RouterVolume", for: String.self, content: { $route in
            let size = Double(1000)
            let initialSize = Size3D(width: size, height: size, depth: size)
            let scaler = 4.0
            ConceptRouter(route: $route)
                .environment(appModel)
                .frame(minWidth: initialSize.width, maxWidth: initialSize.width * scaler,
                       minHeight: initialSize.height, maxHeight: initialSize.height * scaler)
                .frame(minDepth: initialSize.depth, maxDepth: initialSize.depth * scaler)

        })
        .windowStyle(.volumetric)
        .defaultWindowPlacement { content, context in
            let size = content.sizeThatFits(.unspecified)
            if let mainWindow = context.windows.first {
                return WindowPlacement(.trailing(mainWindow), size: size)
            }
            return WindowPlacement(.none)
        }
        .windowResizability(.contentSize)

        // 4. Space: Use this immersive scene to open a concept in a mixed immersive space
        ImmersiveSpace(id: "RouterSpace", for: String.self, content: { $route in
            ConceptRouter(route: $route)
                .environment(appModel)
        })
        .immersiveEnvironmentBehavior(.coexist)

        // 5. Space Full: Use this immersive scene to open a concept in a full immersive space
        ImmersiveSpace(id: "RouterSpaceFull", for: String.self, content: { $route in
            ConceptRouter(route: $route)
                .environment(appModel)
        })
        .immersionStyle(selection: $conceptImmersionStyle, in: .full)

    }

}
