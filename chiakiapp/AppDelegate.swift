//
//  AppDelegate.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

import SwiftUI

@main
struct ChiakiApp: App {
    
    @StateObject var model = AppUiModel()
    
    var body: some Scene {
        Window("Chiaki App", id: "main") {
            InitDiscoverView()
                .environmentObject(model)
        }
        Window("Stream", id: "stream") {
            StreamView()
                .environmentObject(model)
        }
    }
}

struct InitDiscoverView: View {
    
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
                ConsoleListView(discover: d)
                    .environmentObject(d)
            }
        }
        .onAppear {
            setup()
        }
    }
}
