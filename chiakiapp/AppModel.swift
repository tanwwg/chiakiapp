//
//  AppModel.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 30/3/22.
//

import Foundation
import SwiftUI
import Network

struct HostRegistration: Codable {
    var hostId: String
    var hostName: String
    var apKey: String
    var apSsid: String
    var apSsid2: String
    var apName: String
    var serverMac: Data
    var serverName: String
    var rpRegistKey: Data
    var rpKeyType: UInt32
    var rpKey: Data
}

enum DiscoverHostState: String {
    case ready, standby, unknown
}

func toHostState(_ state: ChiakiDiscoveryHostState) -> DiscoverHostState {
    switch (state) {
    case CHIAKI_DISCOVERY_HOST_STATE_READY: return .ready
    case CHIAKI_DISCOVERY_HOST_STATE_STANDBY: return .standby
    default: return .unknown
    }
}

struct DiscoverHost: Identifiable {
    var id: String
    var name: String
    var addr: String
    var port: UInt16
    var hostType: String
    var state: DiscoverHostState
    var registration: HostRegistration?
    
    var credentials: UInt64? {
        guard let reg = registration else { return nil }
        let arr = [UInt8](reg.rpRegistKey)
        guard let ix = arr.firstIndex(of: 0) else { return nil }
        let sub = arr[0...ix-1]
        guard let str = String(bytes: sub, encoding: .utf8), let num = UInt64(str, radix: 16) else { return nil }
        return num
    }
}

func cstring(_ s: UnsafePointer<CChar>!) -> String  {
    return String(cString: s, encoding: .utf8) ?? ""
}

func cdata(_ s: UnsafePointer<UInt8>, length: Int) -> Data {
    return Data(bytes: s, count: length)
}

func cdata(_ s: UnsafePointer<CChar>, length: Int) -> Data {
    return Data(bytes: s, count: length)
}

extension UserDefaults {
    func setObject<Object>(_ object: Object, forKey: String) where Object: Encodable {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(object)
        set(data, forKey: forKey)
    }
    
    func getObject<Object>(forKey: String, castTo type: Object.Type) -> Object? where Object: Decodable {
        guard let data = data(forKey: forKey) else { return nil }
        let decoder = JSONDecoder()
        let object = try? decoder.decode(type, from: data)
        return object
    }
}

class ChiakiDiscover: ObservableObject {
    let discover = ChiakiDiscoverBridge()
    
    @Published var hosts: [DiscoverHost] = []
    var registrations: [HostRegistration]
    
    static let REGISTRATIONS_KEY = "registrations"
    
    func registerHosts() {
        for i in 0...hosts.count-1 {
            if let reg = registrations.first(where: { r in r.hostId == hosts[i].id }) {
                hosts[i].registration = reg
            }
        }
    }
    
    func wake(host: DiscoverHost) {
        guard let reg = host.registration else { return }
        let arr = [UInt8](reg.rpRegistKey)
        guard let ix = arr.firstIndex(of: 0) else { return }
        let sub = arr[0...ix-1]
        guard let str = String(bytes: sub, encoding: .utf8), let num = UInt64(str, radix: 16) else { return }
        
        print(str)
        print(num)
        discover.wakeup(host.addr, key: num)
    }
    
    init() {
        self.registrations = UserDefaults.standard.getObject(forKey: ChiakiDiscover.REGISTRATIONS_KEY, castTo: [HostRegistration].self) ?? []
        
        discover.callback = { (count, hosts) in
            DispatchQueue.main.async {
                self.hosts = (0...count-1).map { i in
                    let h = hosts[i]
                    return DiscoverHost(
                        id: cstring(h.host_id),
                        name: cstring(h.host_name),
                        addr: cstring(h.host_addr),
                        port: h.host_request_port,
                        hostType: cstring(h.host_type),
                        state: toHostState(h.state)
                    )
                }
                self.registerHosts()
            }
        }
        discover.discover()
    }
    
    func save(_ reg: HostRegistration) {
        if let idx = registrations.firstIndex(where:{ h in
            h.hostId == reg.hostId
        }) {
            registrations.remove(at: idx)
        }
        registrations.append(reg)
        
        UserDefaults.standard.setObject(registrations, forKey: ChiakiDiscover.REGISTRATIONS_KEY)
        UserDefaults.standard.synchronize()
        
        self.registerHosts()
    }
}



enum ChiakiRegisterError: Error {
    case invalidPsn
    case invalidPin
}

class ChiakiRegister: ObservableObject, Identifiable {
    let discover: ChiakiDiscover
    let register = ChiakiRegisterBridge()
    let host: DiscoverHost
    
    var id: String { host.id }
    
    @Published var isFinished = false
    @Published var errorStr: String?
    
    init(discover: ChiakiDiscover, host: DiscoverHost, psn: Data, pin: Int) {
        self.discover = discover
        self.host = host
        
        register.callback = { (evt) in
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

                DispatchQueue.main.async { self.discover.save(reg) }
            }

            DispatchQueue.main.async {
                if evtType != CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS {
                    self.errorStr = "err"
                }
                self.isFinished = true
                print("register callback finished!")
            }
        }
        
        register.regist(withPsn: psn, host: host.addr, pin: pin)
    }
    
    deinit {
        register.cancel()
    }
}

class AppUiModel: ObservableObject {
    @Published var register: ChiakiRegister?
    @Published var session: ChiakiSessionBridge?
    
    var discover = ChiakiDiscover()
    let psDiscover = PsDiscover()
    
    @Published var keymap: [InputStep] = []
    
    @AppStorage("keymapFile") var keymapFile: String = ""
    @AppStorage("keymap") var keymapStore: String?

    @AppStorage("isStartStreamCommand") var isStartStreamCommand = false
    @AppStorage("startStreamCommand") var startStreamCommand = ""

    var startStreamCommandProp: String? {
        get {
            if !isStartStreamCommand { return nil }
            return startStreamCommand
        }
    }
    
    func loadBundleAsString(bundle: String, ext:String) -> String {
        guard let res = Bundle.main.url(forResource: bundle, withExtension: ext),
              let jd = try? Data(contentsOf: res),
              let s = String(data: jd, encoding: .utf8) else { return "" }
        return s
    }
    
    func loadStartupKeymap() {
        if let kms = self.keymapStore, let km = try? loadKeymapFile(string: kms) {
            self.keymap = km
        } else {
            let bundle = loadBundleAsString(bundle: "default-map", ext: "json")
            self.keymapStore = bundle
            self.keymapFile = "default-map"
            self.keymap = try! loadKeymapFile(string: bundle)
        }
    }
    
    func loadKeymap(url: URL) throws -> [InputStep] {
        let data = try Data(contentsOf: url)
        let inp = try loadKeymapFile(data: data)
        
        self.keymapStore = String(data: data, encoding: .utf8)
        self.keymapFile = url.lastPathComponent
        self.keymap = inp
        
        return inp
    }
    
    func wake(host: DiscoverHost) {
        guard let ip = IPv4Address(host.addr) else { return }
        guard let creds = host.credentials else { return }
        
        psDiscover.sendWakeup(host: ip, credentials: "\(creds)")
    }
    
    init() {
        loadStartupKeymap()
    }
    
    static var global = AppUiModel()
}
