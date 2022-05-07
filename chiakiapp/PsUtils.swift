//
//  PsUtils.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 6/5/22.
//

import Foundation
import Network

class UdpListen {
    
    let fd: Int32
    let queue = DispatchQueue(label: "UdpListen")
    let receiveCallback: (String, String) -> (Void)
    
    init(address: sockaddr_in, callback: @escaping (String, String) -> Void) throws {
        
        self.receiveCallback = callback
        
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        if fd < 0 { throw getErrNo(label: "socket()") }

        try Sockets.setSocketOption(fd: fd, opt1: SOL_SOCKET, opt2: SO_BROADCAST, value: 1)
//        try Sockets.bindSocket(fd: fd, address: address)
    }
    
    func start() {
        queue.async {
            while self.tryReceive() {
                
            }
            print("listen exit")
        }
    }
    
    func tryReceive() -> Bool {
        return (try? Sockets.receive(fd: fd, maxSize: 2048) { host, data in
            self.receiveCallback(host, data)
        }) ?? false
    }
    
    func send(address: sockaddr_in, data: Data) {
//        guard let addr = Sockets.createSocketAddr(host: "255.255.255.255", port: 9302) else { return }
        try? Sockets.send(fd: fd, address: address, data: data)
    }
    
    deinit {
        close(fd)
    }
}

class PsDiscover {
    
    let queue = DispatchQueue(label: "PsDiscover")
        
    var listener: UdpListen?
    
    var callback: ((DiscoverHost) -> Void)?
    
    init() {
        if let addr = Sockets.createSocketAddr(host: "255.255.255.255", port: 9302) {
            listener = try? UdpListen(address: addr) { host, s in
                self.parseReply(host: host, reply: s)
            }
            listener?.start()
        }

    }
    
    var endDiscover: Double?
    
    func startDiscover(seconds: Double) {
        endDiscover = Date.timeIntervalSinceReferenceDate + seconds
        queueDiscover()
    }
    
    func queueDiscover() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            self.sendDiscover()
            
            let now = Date.timeIntervalSinceReferenceDate
            if let endd = self.endDiscover, now < endd {
                self.queueDiscover()
            }
        }
    }
    
    func parseReply(host: String, reply: String) {
//        print("Received \(reply) from \(host)")
        
        var arr = reply.split(separator: "\n")
        var state = DiscoverHostState.unknown
        if let firstLine = arr.first {
            if firstLine == "HTTP/1.1 200 Ok" {
                state = .ready
            } else if firstLine == "HTTP/1.1 620 Server Standby" {
                state = .standby
            }
        }
        
        arr.removeFirst()
        
        let dict = Dictionary(uniqueKeysWithValues: arr.compactMap { s -> (String, String)? in
            let ss = s.split(separator: ":")
            guard ss.count == 2 else { return nil }
            return (String(ss[0]), String(ss[1]))
        })
        
        guard let hostid = dict["host-id"],
              let name = dict["host-name"],
              let hostType = dict["host-type"],
              let hostPostStr = dict["host-request-port"],
              let hostPort = UInt16(hostPostStr) else {
            return
        }
        
        
        let discoverHost = DiscoverHost(id: hostid, name: name, addr: host, port: hostPort, hostType: hostType, state: state)
//        print(discoverHost)
        callback?(discoverHost)
    }
        
    func sendWakeup(host: String, credentials: String) {
        let str = String(format: "WAKEUP * HTTP/1.1\n" +
                         "client-type:vr\n" +
                         "auth-type:R\n" +
                         "model:w\n" +
                         "app-type:r\n" +
                         "user-credential:%@\n" +
                         "device-discovery-protocol-version:%@\n", credentials, "00030010")
        guard let addr = Sockets.createSocketAddr(host: host, port: 9302) else { return }
        guard let data = str.data(using: .utf8) else { return }
        listener?.send(address: addr, data: data)
    }

    func sendDiscover() {
        let str = "SRCH * HTTP/1.1\ndevice-discovery-protocol-version:00030010\n"

        guard let data = str.data(using: .utf8) else { return }
        guard let addr = Sockets.createSocketAddr(host: "255.255.255.255", port: 9302) else { return }
        listener?.send(address: addr, data: data)
        
    }
    
}

