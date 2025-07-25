# iOS-Worker

iOS-Worker 是一个基于 Vapor 框架开发的 iOS 端 OCR 识别服务组件，作为 YOCR 分布式 OCR 集群中的工作节点（Worker）运行。它负责接收来自主控端 Mac-Master 的 OCR 请求，利用 iOS 设备的 Vision 框架进行图片文字识别，并将结果返回。

## 功能与作用
- 提供 HTTP API 接口，支持图片 OCR 识别请求。
- 支持健康检查、设备信息、状态查询等接口。
- 通过 Bonjour 实现服务自动发现，便于主控端动态发现可用 Worker。
- 充分利用 iOS 设备的算力，实现高效的本地文字识别。

## 主要接口
- `POST /ocr`：接收 base64 图片数据，返回识别结果。
- `GET /health`：健康检查。
- `GET /info`：获取设备与 Worker 信息。
- `GET /status`：获取设备运行状态。

## 配合 YOCRWorkerDemo 使用
YOCRWorkerDemo 是一个用于演示和测试 iOS-Worker 的 iOS 客户端 Demo。通过该 Demo，可以发现局域网内的 Worker 节点，发送图片进行 OCR 识别，并展示识别结果。

### 使用示例
1. 在 iOS 设备上部署 并启动 YOCRWorkerDemo iOS-Worker 服务。
2. 确保与 mac maste 处于同一局域网。

## 依赖
- [Vapor](https://vapor.codes/) 作为服务端框架
- iOS Vision 框架用于 OCR

## 适用场景
- 局域网内多设备协同 OCR 识别
- 利用 iOS 设备算力进行分布式文字识别

---
如需详细开发或部署说明，请参考源码注释或联系开发者。 