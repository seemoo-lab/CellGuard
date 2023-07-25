//
//  LocationNetworkAuthorization.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

// Author: Tal Sahar
// Source: https://stackoverflow.com/a/67758105

import Foundation
import Network
import OSLog

@available(iOS 14.0, *)
public class LocalNetworkAuthorization: NSObject, ObservableObject {
    
    public static let shared = LocalNetworkAuthorization(
        checkNow: UserDefaults.standard.bool(forKey: UserDefaultsKeys.introductionShown.rawValue)
    )
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LocalNetworkAuthorization.self)
    )
    
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    init(checkNow: Bool) {
        super.init()
        
        if (checkNow) {
            requestAuthorization { _ in }
        }
    }
    
    // TODO: Handle
    @Published var lastResult: Bool?
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Create parameters, and allow browsing over peer-to-peer link.
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Browse for a custom service type.
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                Self.logger.debug("Browser failed: \(error.localizedDescription)")
            case .ready, .cancelled:
                break
            case let .waiting(error):
                Self.logger.info("Local network permission has been denied: \(error)")
                self.reset()
                DispatchQueue.main.async {
                    self.lastResult = false
                    self.completion?(false)
                }
            default:
                break
            }
        }
        
        self.netService = NetService(domain: "local.", type:"_lnp._tcp.", name: "LocalNetworkPrivacy", port: 1100)
        self.netService?.delegate = self
        
        self.browser?.start(queue: .main)
        self.netService?.publish()
    }
    
    private func reset() {
        self.browser?.cancel()
        self.browser = nil
        self.netService?.stop()
        self.netService = nil
    }
}

@available(iOS 14.0, *)
extension LocalNetworkAuthorization : NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        self.reset()
        Self.logger.info("Local network permission has been granted")
        DispatchQueue.main.async {
            self.lastResult = true
            self.completion?(true)
        }
    }
}
