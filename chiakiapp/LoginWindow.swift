//
//  LoginWindow.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 20/4/22.
//

import Foundation
import WebKit
import SwiftUI

class LoginUiModel: ObservableObject {
    @Published var loginCode: String?
    
}

struct AccessTokenJson: Codable {
    var access_token: String
}

struct UserIdJson: Codable {
    var user_id: String
}

class LoginWindow: NSViewController, WKNavigationDelegate {
    
    let loginUrl = "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/authorize?service_entity=urn:service-entity:psn&response_type=code&client_id=ba495a24-818c-472b-b12d-ff231c1b5745&redirect_uri=https://remoteplay.dl.playstation.net/remoteplay/redirect&scope=psn:clientapp&request_locale=en_US&ui=pr&service_logo=ps&layout_type=popup&smcid=remoteplay&prompt=always&PlatformPrivacyWs1=minimal&"
    
    let tokenUrl = "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/token"
    
    let CLIENT_ID = "ba495a24-818c-472b-b12d-ff231c1b5745"
    let CLIENT_SECRET = "mvaiZkRsAsI1IBkY"
    
    static let PsnIdFetched = Notification.Name.init("PsnIdFetched")
    
    @IBOutlet var webView: WKWebView!
    @IBOutlet var urlField: NSTextField!
    @IBOutlet var progressView: NSProgressIndicator!
    
    var netTask: URLSessionDataTask?
    
    var ui = LoginUiModel()
    
    required init?(coder:   NSCoder) {
        super.init(coder: coder)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let u = webView.url {
            self.urlField.stringValue = u.absoluteString
            print(u.absoluteString)
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url?.absoluteString,
              let urlcomp = URLComponents(string: url),
              let q = urlcomp.queryItems,
              let codeq = q.first(where: {it in it.name == "code"}),
              let code = codeq.value
              else { return }
        
        self.receivedCode(code: code)
    }
    
    func receivedUserId(_ user_id: String) {
        print(user_id)
        
        guard let i = Int(user_id) else {
            print("cannot convert")
            return
        }
        let s = withUnsafeBytes(of: i) { Data($0).base64EncodedString() }
        print(s)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: LoginWindow.PsnIdFetched, object: s)            
            self.view.window?.close()
        }
        
    }
    
    func receivedAccessToken(_ access_token: String) {
        print("access_token=\(access_token)")
        
        var req = URLRequest(url: URL(string: "\(tokenUrl)/\(access_token)")!)
        let authData = "\(CLIENT_ID):\(CLIENT_SECRET)".data(using: .utf8)!.base64EncodedString()
        req.setValue("Basic \(authData)", forHTTPHeaderField: "Authorization")
        
        let dataTask = URLSession.shared.dataTask(with: req) { data, resp, err in
//            print("\(String(data: data!, encoding: .utf8)) \(resp)")
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let d = data,
                  let json = try? JSONDecoder().decode(UserIdJson.self, from: d) else { return }
            self.receivedUserId(json.user_id)
        }
        dataTask.resume()
        netTask = dataTask
    }
    
    func receivedCode(code: String) {
        print("code=\(code)")
        
        self.webView.isHidden = true
        self.urlField.isHidden = true
        self.progressView.isHidden = false
        self.progressView.startAnimation(self)
        
        var req = URLRequest(url: URL(string: tokenUrl)!)
        req.httpMethod = "POST"
        
        let postBody = "grant_type=authorization_code&redirect_uri=https://remoteplay.dl.playstation.net/remoteplay/redirect&code=\(code)"
        print(postBody)
        req.httpBody = postBody.data(using: .ascii)
        req.setValue("Content-Type", forHTTPHeaderField: "application/x-www-form-urlencoded")
        let authData = "\(CLIENT_ID):\(CLIENT_SECRET)".data(using: .utf8)!.base64EncodedString()
        req.setValue("Basic \(authData)", forHTTPHeaderField: "Authorization")
        
        let dataTask = URLSession.shared.dataTask(with: req) { data, resp, err in
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let d = data,
                  let json = try? JSONDecoder().decode(AccessTokenJson.self, from: d) else {
                      print("unable to parse data")
                      return
                  }
            self.receivedAccessToken(json.access_token)
        }
        dataTask.resume()
        netTask = dataTask
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL(string: loginUrl)!))
    }
    
}
