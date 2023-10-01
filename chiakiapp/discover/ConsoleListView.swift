//
//  ConsoleListView.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

import SwiftUI

struct ConsoleListView: View {
    @Environment(AppUiModel.self) var ui
    
    @ObservedObject var discover: ChiakiDiscover
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Setup")) {
                        NavigationLink(destination: DescribeKeymapView(steps: ui.keymap)) {
                            Text("\(ui.keymapFile)")
                        }
//                        NavigationLink(destination: PreferencesView()) {
//                            Text("Preferences")
//                        }
                    }
                    Section(header: Text("Consoles")) {
                        ForEach(discover.hosts) { host in
                            NavigationLink(destination: HostView(host: host)) {
                                Text(host.name)
                                    .fontWeight(host.registration == nil ? .regular : .bold)
                                    .foregroundColor(host.state == .ready ? Color.black : Color.gray)
                            }
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                HStack {
                    Spacer()
                    Button(action: { discover.discover.sendDiscover() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(5.0)
            }
        }
//        .sheet(item: ui.register, onDismiss: {
//            
//        }, content: { item in
//            RegisterProcessView(register: item, onDone: { ui.register = nil })
//                .frame(width: 300, height: 150)
//        })
//        .environment(ui)

    }
}

struct PreferencesView: View {
    
    @Environment(AppUiModel.self) var ui

    var body: some View {
        EmptyView()
//        Form {
//            HStack {
//                Toggle(isOn: ui.$isStartStreamCommand) {
//                    
//                }
//                TextField("Start stream command", text: ui.$startStreamCommand)
//                    .disabled(!ui.isStartStreamCommand)
//            }
//            Text("Ideally disable airdrop / bluetooth / location services when starting a stream")
//        }
//        .padding()
    }
}

struct DescribeKeymapView: View {
    let keymap: [String]
    
    @State var openKeymap = false
    @Environment(AppUiModel.self) var ui
    
    init(steps: [InputStep]) {
        self.keymap = steps.map { s in s.describe() }
    }
    
    var body: some View {
        VStack {
            Button(action: { openKeymap = true }) {
                Text("Open")
            }
            Text("\(keymap.count) items")
            List(keymap, id: \.self) { s in
                Text(s)
            }
        }
        .fileImporter(isPresented: $openKeymap, allowedContentTypes: [.json]) { result in
            guard let url = try? result.get() else { return }
            try? ui.loadKeymap(url: url)
        }
    }
}


struct HostView: View {
    @Environment(AppUiModel.self) var ui
    @EnvironmentObject var discover: ChiakiDiscover
    let host: DiscoverHost
    
    @Environment(\.openWindow) private var openWindow
    
//    func wake() {
//        discover.discover.sendWakeup(host: <#T##String#>, credentials: <#T##String#>)
//        ui.wake(host: host)
//    }
    
    func startSession() {
        guard let reg = host.registration else { return }
                
        let session = ChiakiSessionBridge()
        session.host = host.addr;
        session.registKey = reg.rpRegistKey;
        session.morning = reg.rpKey;
        
        var packetCount = 0
        session.callback = { data in
            packetCount += 1
            print(data)
        }
        
        ui.stream = StreamController(app: ui, session: session)
//        ui.session = session
        
//        openWindow(id: "stream")
    }
    
    var body: some View {
        VStack {
            if host.registration != nil {
                Text(host.name)
                Text(host.addr)
                Text(host.state.rawValue)
                Button(action: { discover.wake(host: host) }) {
                    Text("Wake")
                }
                
                Button(action: { startSession() }) {
                    Text("Stream")
                }
            } else {
                RegisterView(host: host)
            }
        }
    }
}



//struct RegisterView_Previews: PreviewProvider {
//    static var previews: some View {
//        RegisterView()
//    }
//}
