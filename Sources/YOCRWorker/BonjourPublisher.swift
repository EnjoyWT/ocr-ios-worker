//
//  BonjourPublisher.swift
//  iOS-Worker
//

import Foundation
import Logging
import Network

final class BonjourPublisher: NSObject {
    static let serviceType = "_ocr._tcp."
    
    private let logger = Logger(label: "bonjour-publisher")
    private var netService: NetService?
    private let deviceId: String
    private let port: Int
    
    init(deviceId: String, port: Int = 8080) {
        self.deviceId = deviceId
        self.port = port
        super.init()
    }
    
    deinit {
        stopPublishing()
    }
    
    func startPublishing() {
        // 先停止之前的服务
        stopPublishing()
        logger.info("Starting Bonjour service publishing", metadata: [
            "deviceId": "\(deviceId)",
            "port": "\(port)"
        ])
        
        netService = NetService(domain: "local.", type: Self.serviceType, name: deviceId, port: Int32(port))
        netService?.delegate = self

        // 重要：确保在主线程设置delegate
//        DispatchQueue.main.async {
        // 设置服务的TXT记录（可选的元数据）
        var txtData: [String: Data] = [:]
        txtData["version"] = "1.0".data(using: .utf8)
        txtData["capabilities"] = "vision".data(using: .utf8)
        txtData["platform"] = "iOS".data(using: .utf8)
            
        netService?.setTXTRecord(NetService.data(fromTXTRecord: txtData))
            
        // 延迟发布以确保网络服务完全就绪
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        netService?.publish()
        logger.info("NetService publish() called")
//        }
//        }
    }
    
    func stopPublishing() {
        logger.info("Stopping Bonjour service publishing")
        netService?.stop()
        netService = nil
    }
    
    // 广播成功后，等待 master 连接时调用
    func notifyWaitingMaster() {
        NotificationCenter.default.post(
            name: .workerStatusChanged,
            object: nil,
            userInfo: ["status": WorkerStatus.waitingMaster.rawValue]
        )
    }
    // 广播失败后自动重试时调用
    func notifyRetrying() {
        NotificationCenter.default.post(
            name: .workerStatusChanged,
            object: nil,
            userInfo: ["status": WorkerStatus.retrying.rawValue]
        )
    }
}

// MARK: - NetServiceDelegate

extension BonjourPublisher: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        logger.info("Service published successfully", metadata: [
            "name": "\(sender.name)",
            "domain": "\(sender.domain)",
            "type": "\(sender.type)"
        ])
        NotificationCenter.default.post(
            name: .workerStatusChanged,
            object: nil,
            userInfo: ["status": WorkerStatus.broadcastSuccess.rawValue]
        )
        // 广播成功后，进入等待 master 状态
        notifyWaitingMaster()
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        logger.error("Failed to publish service", metadata: [
            "name": "\(sender.name)",
            "error": "\(errorDict)"
        ])
        NotificationCenter.default.post(
            name: .workerStatusChanged,
            object: nil,
            userInfo: ["status": WorkerStatus.broadcastFailed.rawValue]
        )
    }
    
    func netServiceWillResolve(_ sender: NetService) {
        logger.info("Service will resolve", metadata: ["name": "\(sender.name)"])
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        logger.info("Service resolved", metadata: [
            "name": "\(sender.name)",
            "addresses": "\(sender.addresses?.count ?? 0)"
        ])
    }
    
    func netServiceDidStop(_ sender: NetService) {
        print("======4")
        logger.info("Service stopped", metadata: ["name": "\(sender.name)"])
    }
}
