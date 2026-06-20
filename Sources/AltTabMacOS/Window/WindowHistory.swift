import Foundation

@MainActor
final class WindowHistory {
    private var orderedIdentities: [WindowIdentity] = []

    func stop() {
        orderedIdentities.removeAll()
    }

    func noteActivation(from previous: WindowIdentity?, to entry: WindowEntry) {
        recordTransition(from: previous, to: entry.identity)
    }

    func order(entries: [WindowEntry], current: WindowIdentity?) -> [WindowEntry] {
        let shouldUseHistory = current != nil && orderedIdentities.first == current
        let historyIndex = shouldUseHistory
            ? Dictionary(uniqueKeysWithValues: orderedIdentities.enumerated().map { ($0.element, $0.offset) })
            : [:]
        return entries.sorted { lhs, rhs in
            if lhs.identity == current, rhs.identity != current { return true }
            if rhs.identity == current, lhs.identity != current { return false }
            let lhsIdx = historyIndex[lhs.identity]
            let rhsIdx = historyIndex[rhs.identity]
            if let lhsIdx, let rhsIdx, lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
            if lhsIdx != nil, rhsIdx == nil { return true }
            if rhsIdx != nil, lhsIdx == nil { return false }
            return lhs.zIndex < rhs.zIndex
        }
    }

    private func recordTransition(from previous: WindowIdentity?, to current: WindowIdentity) {
        orderedIdentities.removeAll { $0 == current }
        orderedIdentities.insert(current, at: 0)
        if let previous, previous != current {
            orderedIdentities.removeAll { $0 == previous }
            orderedIdentities.insert(previous, at: min(1, orderedIdentities.count))
        }
        if orderedIdentities.count > 64 {
            orderedIdentities.removeLast(orderedIdentities.count - 64)
        }
    }
}
