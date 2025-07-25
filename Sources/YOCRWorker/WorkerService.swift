//
//  main.swift
//  iOS-Worker
//

import Logging
import UIKit
import Vapor

public final class WorkerService {
    public static let shared = WorkerService()
    private var app: Application?
    private var bonjourPublisher: BonjourPublisher?
    private var deviceId: String = ""
    private var isRunning = false
    private var logHandler: ((String) -> Void)?
    
    private init() {}
    
    /// 启动 HTTP + Bonjour 服务
    /// - Parameters:
    ///   - port: 监听端口，默认 8080
    ///   - log: 日志回调
    public func start(port: Int = 8080, log: ((String) -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        logHandler = log
        deviceId = Self.generateDeviceId()
        logHandler?("[启动] 设备ID: \(deviceId)")
        NotificationCenter.default.post(
            name: .workerStatusChanged,
            object: nil,
            userInfo: ["status": WorkerStatus.starting.rawValue]
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var env = try Environment.detect()
                try LoggingSystem.bootstrap(from: &env)
                let app = Application(env)
                self.app = app
                try configure(app, deviceId: self.deviceId, port: port)
                self.logHandler?("[HTTP] 服务已启动: http://localhost:\(port)")
             
                // Bonjour 必须切回主线程启动
                DispatchQueue.main.async {
                    self.bonjourPublisher = BonjourPublisher(deviceId: self.deviceId, port: port)
                    self.bonjourPublisher?.startPublishing()
                    self.logHandler?("[Bonjour] 服务已发布")
                }

                try app.run()
            } catch {
                self.logHandler?("[错误] \(error.localizedDescription)")
            }
        }
    }
    
    /// 停止服务
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        bonjourPublisher?.stopPublishing()
        app?.shutdown()
        logHandler?("[停止] 服务已关闭")
    }
    
    public var currentDeviceId: String { deviceId }
    
    private static func generateDeviceId() -> String {
        let device = UIDevice.current
        let deviceName = device.name.replacingOccurrences(of: " ", with: "-")
        let timestamp = String(Int(Date().timeIntervalSince1970))
        return "iOS-\(deviceName)-\(timestamp)"
    }
}

// MARK: - Vapor 配置

private func configure(_ app: Application, deviceId: String, port: Int) throws {
    app.logger.logLevel = .info
    try app.register(collection: WorkerController(deviceId: deviceId))
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port
//    app.http.server.configuration.supportVersions = [.one] // 强制 HTTP/1.1
    app.logger.info("YOCRWorker 服务配置完成")
}
