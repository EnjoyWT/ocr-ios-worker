//
//  WorkerModels.swift
//  iOS-Worker
//

import Foundation
import Vapor

// 共享的OCR模型（与Mac端保持一致）
struct OCRRequest: Content {
    let image: String?           // base64编码的图片数据
    let language: String?
    let recognitionLevel: String?
    let confidence: Float?
}

struct OCRResponse: Content {
    let status: String
    let data: OCRData?
    let error: String?
    let processedBy: String?

    struct OCRData: Content {
        let text: String
        let confidence: Float
        let processingTime: Int
        let boundingBoxes: [BoundingBox]?
    }

    struct BoundingBox: Content {
        let text: String
        let confidence: Float
        let x: Float
        let y: Float
        let width: Float
        let height: Float
    }
}

extension OCRResponse {
    static func success(data: OCRData, processedBy: String) -> OCRResponse {
        return OCRResponse(status: "success", data: data, error: nil, processedBy: processedBy)
    }

    static func failure(error: String) -> OCRResponse {
        return OCRResponse(status: "error", data: nil, error: error, processedBy: nil)
    }
}

struct WorkerInfo: Content {
    let deviceId: String
    let deviceName: String
    let version: String
    let capabilities: [String]
    let status: String
}