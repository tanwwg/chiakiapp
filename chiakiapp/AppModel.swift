//
//  AppModel.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 30/3/22.
//

import Foundation

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
    
    @Published var keymap: [InputStep] = []
    @Published var keymapFile: String = ""

    static let isStartStreamCommandStorageKey = "isStartStreamCommand"
    static let startStreamCommandStorageKey = "startStreamCommand"
    var startStreamCommand: String? {
        get {
            let b = UserDefaults.standard.bool(forKey: AppUiModel.isStartStreamCommandStorageKey)
            if !b { return nil }
            return UserDefaults.standard.string(forKey: AppUiModel.startStreamCommandStorageKey)
        }
    }
    
    func loadDefaultKeymap() -> String {
        guard let res = Bundle.main.url(forResource: "default-map", withExtension: "json"),
              let jd = try? Data(contentsOf: res),
              let s = String(data: jd, encoding: .utf8) else { return "" }
        return s
    }
    
    func saveDefaultKeymap() {
        if UserDefaults.standard.string(forKey: "keymap") == nil {
            UserDefaults.standard.set(loadDefaultKeymap(), forKey: "keymap")
            UserDefaults.standard.set("default-map", forKey: "keymapFile")
            UserDefaults.standard.synchronize()
        }
    }
    
    func loadStartupKeymap() {
        guard let km = UserDefaults.standard.string(forKey: "keymap"),
              let data = km.data(using: .utf8),
              let inp = try? loadKeymapFile(data: data) else { return }
        self.keymap = inp
        self.keymapFile = UserDefaults.standard.string(forKey: "keymapFile") ?? ""
    }
    
    func loadKeymap(url: URL) throws -> [InputStep] {
        let data = try Data(contentsOf: url)
        let inp = try loadKeymapFile(data: data)
        
        UserDefaults.standard.set(String(data: data, encoding: .utf8), forKey: "keymap")
        UserDefaults.standard.set(url.lastPathComponent, forKey: "keymapFile")
        UserDefaults.standard.synchronize()
        
        self.keymap = inp
        self.keymapFile = url.lastPathComponent
        
        return inp
    }
    
    init() {
        saveDefaultKeymap()
        loadStartupKeymap()
    }
    
    static var global = AppUiModel()
}
