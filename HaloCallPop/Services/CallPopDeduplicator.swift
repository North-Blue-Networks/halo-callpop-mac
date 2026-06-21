import Foundation

actor CallPopDeduplicator {
    private var recentCallApiIds: [String: Date] = [:]
    private let window: TimeInterval

    init(window: TimeInterval = 60) {
        self.window = window
    }

    func shouldProcess(callApiId: String, now: Date = Date()) -> Bool {
        purgeExpired(now: now)
        if recentCallApiIds[callApiId] != nil {
            return false
        }
        recentCallApiIds[callApiId] = now
        return true
    }

    private func purgeExpired(now: Date) {
        recentCallApiIds = recentCallApiIds.filter { now.timeIntervalSince($0.value) < window }
    }
}
