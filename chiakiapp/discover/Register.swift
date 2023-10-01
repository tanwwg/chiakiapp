//
//  Register.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 2/10/23.
//

import SwiftUI


enum ChiakiRegisterError: Error {
    case invalidPsn
    case invalidPin
}

struct RegistrationInfo {
    let host: DiscoverHost
    let psn: Data
    let pin: Int
}

@Observable class ChiakiRegister {
    let discover: ChiakiDiscover
    let register = ChiakiRegisterBridge()
    let host: DiscoverHost
    
    var isFinished = false
    var errorStr: String?
    
    init(discover: ChiakiDiscover, host: DiscoverHost, psn: Data, pin: Int) {
        self.discover = discover
        self.host = host
        
        register.callback = { [weak self] (evt) in
            let evtType = evt.pointee.type
            if evtType == CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS {
                var r = evt.pointee.registered_host.unsafelyUnwrapped.pointee
                let reg = HostRegistration(
                    hostId: host.id,
                    hostName: host.name,
                    apKey: cstring(&r.ap_key.0),
                    apSsid: cstring(&r.ap_ssid.0),
                    apSsid2: cstring(&r.ap_bssid.0),
                    apName: cstring(&r.ap_name.0),
                    serverMac: cdata(&r.server_mac.0, length: 6),
                    serverName: cstring(&r.server_nickname.0),
                    rpRegistKey: cdata(&r.rp_regist_key.0, length: 16),
                    rpKeyType: r.rp_key_type,
                    rpKey: cdata(&r.rp_key.0, length: 16))

                DispatchQueue.main.async { self?.discover.save(reg) }
            }

            DispatchQueue.main.async {
                if evtType != CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS {
                    self?.errorStr = "err"
                }
                self?.isFinished = true
                print("register callback finished!")
            }
        }
        
        register.regist(withPsn: psn, host: host.addr, pin: pin)
    }
    
    deinit {
        register.cancel()
    }
}

struct RegisterView: View {
    @Environment(AppUiModel.self) var ui
    @EnvironmentObject var discover: ChiakiDiscover
    
    let host: DiscoverHost
    @State var psnid: String = ""
    @State var pin: String = ""
    @State var err: String?
    
    @State var isRegister = false
    
    let pub = NotificationCenter.default.publisher(for: LoginWindow.PsnIdFetched)
    
    func register() {
        guard Data(base64Encoded: psnid) != nil else {
            err = "Invalid psn id"
            return
        }
        guard Int(pin) != nil else {
            err = "Pin must be numeric"
            return
        }
        isRegister = true
//        ui.register = ChiakiRegister(discover: discover, host: host, psn: psndata, pin: pinInt)
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
        .sheet(isPresented: $isRegister) {
            RegisterProcessView(registration: RegistrationInfo(host: host, psn: Data(base64Encoded: psnid)!, pin: Int(pin)!))
        }
    }
}

struct RegisterProcessView: View {
    var registration: RegistrationInfo
    @State var regproc: SetupValue<ChiakiRegister> = .uninitialized
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var discover: ChiakiDiscover
    
    func setup() {
        if case .uninitialized = regproc {
            regproc = .value(ChiakiRegister(discover: discover, host: registration.host, psn: registration.psn, pin: registration.pin))
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text("Registering \(registration.host.name)")
            switch(regproc) {
            case .value(let register):
                Text(register.errorStr ?? "")
                
                if register.isFinished {
                    Button(action: { dismiss() }) {
                        Text("Done")
                    }
                } else {
                    ProgressView()
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                    }
                }
            default: EmptyView()
            }
            Spacer()
        }
        .padding()
    }
}
