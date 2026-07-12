import Foundation

/// Provider 抽象層：permission 事件來源（Claude Code / Codex / Gemini / WebSocket…）。
/// 只負責「產生 request」與「把決策送回來源」；queue、Joy-Con、terminal 都在上層共用。
protocol PermissionProvider: AnyObject {
    var name: String { get }
    func start()
    func stop()
    /// 對某 request 下決策，送回來源解除阻塞。
    func resolve(id: String, decision: PermissionDecision)
    /// 有新 request 時回呼上層（main queue）。
    var onRequest: ((PermissionRequest) -> Void)? { get set }
    /// 來源提前放棄（client 斷線）時回呼上層。
    var onCancel: ((String) -> Void)? { get set }
}
