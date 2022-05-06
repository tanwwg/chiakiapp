//
//  PsUtils.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 6/5/22.
//

import Foundation
import Network

class PsDiscover {
    
    let queue = DispatchQueue(label: "PsDiscover")
    
    func sendWakeup(host: IPv4Address, credentials: String) {
        let conn = NWConnection(host: .ipv4(host), port: 9302, using: .udp)
        
        let str = String(format: "WAKEUP * HTTP/1.1\n" +
                         "client-type:vr\n" +
                         "auth-type:R\n" +
                         "model:w\n" +
                         "app-type:r\n" +
                         "user-credential:%@\n" +
                         "device-discovery-protocol-version:%@\n", credentials, "00030010")
        conn.start(queue: queue)
        conn.send(content: str.data(using: .utf8), isComplete: true, completion: .idempotent)
        conn.cancel()
    }

}

