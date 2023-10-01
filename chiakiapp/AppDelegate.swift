//
//  AppDelegate.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

import SwiftUI

extension Notification.Name {
    static let streamDisconnect = Notification.Name("Stream_Disconnect")
}

@main
struct ChiakiApp: App {
    
    @State var model = AppUiModel()
    
    var body: some Scene {
        Window("Chiaki App", id: "main") {
            InitDiscoverView()
                .environment(model)
        }
        .commands {
            CommandMenu("Stream") {
                Button(action: { 
                    NotificationCenter.default.post(name: .streamDisconnect, object: nil)
                }) {
                    Text("Disconnect")
                }
                .keyboardShortcut("d")
                .disabled(model.stream == nil)
            }
        }
//        Window("Stream", id: "stream") {
//            StreamView()
//                .environment(model)
//        }
    }
}

struct InitDiscoverView: View {
    
    @Environment(AppUiModel.self) private var app
    @State var discover: SetupValue<ChiakiDiscover> = .uninitialized
    
    func setup() {
        if case .uninitialized = discover {
            do {
                discover = .value(ChiakiDiscover(try PsDiscover()))
            } catch {
                discover = .error(error)
            }
        }
    }
    
    var body: some View {
        Group {
            switch(discover) {
            case .uninitialized: EmptyView()
            case .error(let e): Text(e.localizedDescription)
            case .value(let d):
                Group {
                    if let stream = app.stream {
                        NsStreamView(streamController: stream)
                    } else {
                        ConsoleListView(discover: d)
                            .environmentObject(d)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .streamDisconnect)) { _ in
                    app.stream = nil
                }
            }
        }
        .onAppear {
            setup()
        }
    }
}
