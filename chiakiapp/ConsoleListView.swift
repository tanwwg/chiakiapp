//
//  ConsoleListView.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

import SwiftUI

struct AppUiView: View {
    @StateObject var ui = AppUiModel()
    
    var body: some View {
        ConsoleListView(discover: ui.discover)
            .environmentObject(ui)
    }
}

struct ConsoleListView: View {
    @EnvironmentObject var ui: AppUiModel
    
    @ObservedObject var discover: ChiakiDiscover
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Setup")) {
                    NavigationLink(destination: DescribeKeymapView(steps: ui.keymap)) {
                        Text("\(ui.keymapFile)")
                    }
                    NavigationLink(destination: PreferencesView()) {
                        Text("Preferences")
                    }
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
        }
        .sheet(item: $ui.register, onDismiss: {
            
        }, content: { item in
            RegisterProcessView(register: item, onDone: { ui.register = nil })
                .frame(width: 300, height: 150)
        })
        .environmentObject(ui)

    }
}

struct PreferencesView: View {
    
    @EnvironmentObject var ui: AppUiModel

    var body: some View {
        Form {
            HStack {
                Toggle(isOn: ui.$isStartStreamCommand) {
                    
                }
                TextField("Start stream command", text: ui.$startStreamCommand)
                    .disabled(!ui.isStartStreamCommand)
            }
            Text("Ideally disable airdrop / bluetooth / location services when starting a stream")
        }
        .padding()
    }
}

struct DescribeKeymapView: View {
    let keymap: [String]
    
    init(steps: [InputStep]) {
        self.keymap = steps.map { s in s.describe() }
    }
    
    var body: some View {
        VStack {
            Text("\(keymap.count) items")
            List(0..<keymap.count) { i in
                Text(keymap[i])
            }
        }
    }
}

struct RegisterProcessView: View {
    @ObservedObject var register: ChiakiRegister
    let onDone: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Text("Registering \(register.host.name)")
            Text(register.errorStr ?? "")
            
            if register.isFinished {
                Button(action: onDone) {
                    Text("Done")
                }
            } else {
                ProgressView()
                Button(action: onDone) {
                    Text("Cancel")
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct HostView: View {
    @EnvironmentObject var ui: AppUiModel
    let host: DiscoverHost
    
    func wake() {
        ui.discover.wake(host: host)
    }
    
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
        
        ui.session = session
        
    }
    
    var body: some View {
        VStack {
            if host.registration != nil {
                Text(host.name)
                Text(host.addr)
                Text(host.state.rawValue)
                Button(action: { wake() }) {
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

struct RegisterView: View {
    @EnvironmentObject var ui: AppUiModel
    
    let host: DiscoverHost
    @State var psnid: String = ""
    @State var pin: String = ""
    @State var err: String?
    
    let pub = NotificationCenter.default.publisher(for: LoginWindow.PsnIdFetched)
    
    func register() {
        guard let psndata = Data(base64Encoded: psnid) else {
            err = "Invalid psn id"
            return
        }
        guard let pinInt = Int(pin) else {
            err = "Pin must be numeric"
            return
        }
        ui.register = ChiakiRegister(discover: ui.discover, host: host, psn: psndata, pin: pinInt)
    }
    
    func fetchPsn() {
        guard let sb = NSStoryboard.main?.instantiateController(withIdentifier: "loginWindow") as? NSWindowController else { return }
        sb.showWindow(self)
    }
    
    var body: some View {
        Form {
            Text(host.name)
            Text(host.addr)
            Text(host.hostType)
            Text(host.state.rawValue)
            
            HStack {
                TextField("PSN ID", text:$psnid)
                Button(action: fetchPsn) {
                    Text("Fetch")
                }
            }
            TextField("Pin", text:$pin)
            Text(err ?? " ")
            
            HStack {
                Spacer()
                                
                Button(action: register) {
                    Text("Register")
                }

            }
            
            Spacer()


        }
        .padding()
        .onReceive(pub) { o in
            if let s = o.object as? String {
                psnid = s
            }
        }
    }
}

//struct RegisterView_Previews: PreviewProvider {
//    static var previews: some View {
//        RegisterView()
//    }
//}
