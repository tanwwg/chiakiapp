//
//  Sockets.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 6/5/22.
//

import Foundation

struct Sockets {

    static func createSocketAddr(host: String, port: UInt16) -> sockaddr_in?
    {
        var inaddr = in_addr()
        let ret = withUnsafeMutablePointer(to: &inaddr) { p in
            host.withCString { cstr in
                inet_aton(cstr, p)
            }
        }
        if ret == 0 { return nil }
        
        return sockaddr_in(
            sin_len:    __uint8_t(MemoryLayout<sockaddr_in>.stride),
            sin_family: sa_family_t(AF_INET),
            sin_port:   in_port_t(port.bigEndian),
            sin_addr:   inaddr,
            sin_zero:   ( 0, 0, 0, 0, 0, 0, 0, 0 )
        )
    }

    static func bindSocket(fd: Int32, address: sockaddr_in) throws {
        let ret = withUnsafePointer(to: address) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { p in
                bind(fd, p, socklen_t(address.sin_len))
            }
        }
        if ret < 0 { throw getErrNo(label: "bind()") }
    }

    static func setSocketOption(fd: Int32, opt1: Int32, opt2: Int32, value: Int32) throws {
        let v = value
        let ret = withUnsafePointer(to: v) { p in
            setsockopt(fd, opt1, opt2, p, socklen_t(MemoryLayout<Int32>.stride))
        }
        if ret < 0 { throw getErrNo(label: "setsockopt") }
    }
    
    static func receive(fd: Int32, maxSize: Int, callback: (String, String) -> Void) throws -> Bool {
        
        var buffer = Data(count: maxSize)
        // not important, will be overriden
        guard var addr = createSocketAddr(host: "127.0.0.1", port: 0) else { throw SocketError.unknownError }
        
        var addrSize: socklen_t = socklen_t(addr.sin_len)
        let arrive = withUnsafeMutablePointer(to: &addr) { ptr -> size_t in
            withUnsafeMutablePointer(to: &addrSize) { addrptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { p in
                    buffer.withUnsafeMutableBytes { bbuf in
                        return recvfrom(fd, bbuf.baseAddress, bbuf.count, 0, p, addrptr)
                    }
                }
            }
        }
        
        
        if arrive > 0 {
            if let s = String(bytes: buffer[0...arrive-1], encoding: .utf8),
               let p = inet_ntoa(addr.sin_addr) {
                callback(String(cString: p), s)
            }
            return true
        } else {
            return false
        }
    }
    
    static func send(fd: Int32, address: sockaddr_in, data: Data) throws {
        let sent = data.withUnsafeBytes { buf in
            withUnsafePointer(to: address) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { p2 in
                    sendto(fd, buf.baseAddress, buf.count, 0, p2, socklen_t(address.sin_len))
                }
            }
        }
        if sent < 0 {
            throw getErrNo(label: "send()")
        }
        print("sent \(sent)")
    }

}




enum SocketError: Error {
    case unknownError
    case errno(message: String)
}

func getErrNo(label: String) -> SocketError {
    let p = strerror(errno)
    guard let s = p else { return .unknownError }
    let errMsg = String(cString: s)
    print("\(label) \(errMsg)")
    return .errno(message: errMsg)
}

