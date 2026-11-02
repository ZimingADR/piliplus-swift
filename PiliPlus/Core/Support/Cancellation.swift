import Foundation

enum Cancellation {
    /// 统一识别 `Task` 取消与 URLSession 取消，避免把用户主动切换页面当成加载失败。
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        if let apiError = error as? BiliAPIError, apiError.code == NSURLErrorCancelled {
            return true
        }
        return false
    }
}
