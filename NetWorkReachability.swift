//
//  NetWorkReachability.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/15.
//

import UIKit
import Alamofire
@objc enum ReachabilityStatus : Int8 {
    case notReachable = 0
    case unknow = 1
    case ethernetOrWiFi = 2
    case wwan = 3
}

@objc class NetWorkReachability: NSObject {
    
    typealias NetworkBlock = (_ status :ReachabilityStatus) -> ()
    
    @objc static let netWork = NetWorkReachability()
    
    private var networkBlocks = [NetworkBlock]()
    
    private lazy var manager = NetworkReachabilityManager()
    
    override init() {
        super.init()
        self.manager!.startListening(onUpdatePerforming: { status in
            if status == NetworkReachabilityManager.NetworkReachabilityStatus.reachable(.ethernetOrWiFi) {
                for networkBlock in self.networkBlocks {
                    networkBlock(.ethernetOrWiFi)
                }
            }
            if status == NetworkReachabilityManager.NetworkReachabilityStatus.notReachable {
                for networkBlock in self.networkBlocks {
                    networkBlock(.notReachable)
                }
            }
            if status == NetworkReachabilityManager.NetworkReachabilityStatus.unknown {
                for networkBlock in self.networkBlocks {
                    networkBlock(.unknow)
                }
            }
            if status == NetworkReachabilityManager.NetworkReachabilityStatus.reachable(.cellular) {
                for networkBlock in self.networkBlocks {
                    networkBlock(.wwan)
                }
            }
        })
    }
    
    @objc func netWorkReachability(_ reachabilityStatus: @escaping(( _ status :ReachabilityStatus) -> ())) {
        self.networkBlocks.append(reachabilityStatus)
    }
    
    @objc func getNetWorkStatus() -> (ReachabilityStatus) {
        if manager!.status == NetworkReachabilityManager.NetworkReachabilityStatus.reachable(.ethernetOrWiFi) {
            return .ethernetOrWiFi
        } else if manager!.status == NetworkReachabilityManager.NetworkReachabilityStatus.reachable(.cellular) {
            return .wwan
        } else if manager!.status == NetworkReachabilityManager.NetworkReachabilityStatus.notReachable {
            return .notReachable
        } else {
            return .unknow
        }
    }
}
