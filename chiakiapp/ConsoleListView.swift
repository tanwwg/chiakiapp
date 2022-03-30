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
            List(discover.hosts) { host in
                NavigationLink(destination: HostView(host: host)) {
                    Text(host.name)
                        .fontWeight(host.registration == nil ? .regular : .bold)
                }
            }
        }
        .sheet(item: $ui.register, onDismiss: {
            
        }, content: { item in
            RegisterProcessView(register: item, onDone: { ui.register = nil })
                .frame(width: 300, height: 150)
        })
        .environmentObject(ui)

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
        session.start()
        
        ui.session = session
        
    }
    
    var body: some View {
        if host.registration != nil {
            Text("registered")
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

struct RegisterView: View {
    @EnvironmentObject var ui: AppUiModel
    
    let host: DiscoverHost
    @State var psnid: String = ""
    @State var pin: String = ""
    @State var err: String?
    
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
    
    var body: some View {
        Form {
            Text(host.name)
            Text(host.addr)
            
            TextField("PSN ID", text:$psnid)
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
    }
}

//struct RegisterView_Previews: PreviewProvider {
//    static var previews: some View {
//        RegisterView()
//    }
//}
