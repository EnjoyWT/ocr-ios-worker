//
//  WorkerController.swift
//  iOS-Worker
//

import Vapor
import UIKit
import Logging
import NotificationCenter

struct WorkerController: RouteCollection {
    private let logger = Logger(label: "worker-controller")
    private let deviceId: String
    
    init(deviceId: String) {
        self.deviceId = deviceId
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.post("ocr", use: processOCR)
        routes.get("health", use: health)
        routes.get("info", use: getInfo)
        routes.get("status", use: getStatus)
        routes.post("onDiscovered", use: onDiscovered)
    }
    
    func processOCR(req: Request) async throws -> OCRResponse {
        logger.info("Received OCR request", metadata: [
            "deviceId": "\(deviceId)",
            "clientIP": "\(req.remoteAddress?.description ?? "unknown")"
        ])
        
        let ocrRequest = try req.content.decode(OCRRequest.self)
        
        // 验证请求
        guard let imageBase64 = ocrRequest.image,
              let imageData = Data(base64Encoded: imageBase64) else {
            logger.warning("Invalid request: missing or invalid image data")
            throw Abort(.badRequest, reason: "Valid base64 image data is required")
        }
        
        do {
            let startTime = Date()
            let result = try await iOSVisionService.shared.recognizeText(
                from: imageData,
                language: ocrRequest.language,
                confidence: ocrRequest.confidence,
                deviceId: deviceId
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            logger.info("OCR request completed successfully", metadata: [
                "deviceId": "\(deviceId)",
                "processingTime": "\(Int(processingTime * 1000))ms",
                "textLength": "\(result.text.count)"
            ])
            
            return OCRResponse.success(data: result, processedBy: deviceId)
            
        } catch {
            logger.error("OCR processing failed", metadata: [
                "deviceId": "\(deviceId)",
                "error": "\(error)"
            ])
            return OCRResponse.failure(error: error.localizedDescription)
        }
    }
    
    func health(req: Request) async throws -> [String: String] {
        return ["status": "ok"]
    }
    
    func getInfo(req: Request) async throws -> WorkerInfo {
        return WorkerInfo(
            deviceId: deviceId,
            deviceName: UIDevice.current.name,
            version: "1.0.0",
            capabilities: ["vision", "ocr"],
            status: "active"
        )
    }
    
    func getStatus(req: Request) async throws -> StatusResponse {
        let processInfo = ProcessInfo.processInfo
        let device = UIDevice.current
        return StatusResponse(
            deviceId: deviceId,
            deviceName: device.name,
            deviceModel: device.model,
            systemVersion: device.systemVersion,
            uptime: processInfo.systemUptime,
            memoryUsage: getMemoryUsage(),
            capabilities: ["vision", "ocr"],
            status: "healthy"
        )
    }
    
    /// master 主动通知 worker 已被发现
    func onDiscovered(req: Request) async throws -> HTTPStatus {
        logger.info("收到 master 的 onDiscovered 通知", metadata: [
            "deviceId": "\(deviceId)",
            "clientIP": "\(req.remoteAddress?.description ?? "unknown")"
        ])
        // 通知 App 层
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .workerStatusChanged,
                object: nil,
                userInfo: ["status": WorkerStatus.connected.rawValue]
            )
        }
        return .ok
    }
    
    // 示例：收到 master 连接前，主动发送 waitingMaster 状态（可在广播成功后调用）
    func notifyWaitingMaster() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .workerStatusChanged,
                object: nil,
                userInfo: ["status": WorkerStatus.waitingMaster.rawValue]
            )
        }
    }
    // 示例：与 master 断开时调用
    func notifyDisconnected() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .workerStatusChanged,
                object: nil,
                userInfo: ["status": WorkerStatus.disconnected.rawValue]
            )
        }
    }
    // 示例：健康检查失败时调用
    func notifyHealthFailed() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .workerStatusChanged,
                object: nil,
                userInfo: ["status": WorkerStatus.healthFailed.rawValue]
            )
        }
    }
    
    private func getMemoryUsage() -> [String: UInt64] {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return [
                "resident": info.resident_size,
                "virtual": info.virtual_size
            ]
        } else {
            return [
                "resident": 0,
                "virtual": 0
            ]
        }
    }
}

struct StatusResponse: Content {
    let deviceId: String
    let deviceName: String
    let deviceModel: String
    let systemVersion: String
    let uptime: Double
    let memoryUsage: [String: UInt64]
    let capabilities: [String]
    let status: String
}

enum WorkerStatus: String {
    case starting, broadcastSuccess, broadcastFailed, waitingMaster, connected, disconnected, retrying, healthFailed
}

// 通知名称扩展
extension Notification.Name {
    static let workerDiscovered = Notification.Name("workerDiscovered")
    static let workerStatusChanged = Notification.Name("workerStatusChanged")
}