import SwiftUI

extension TaskItem {
    /// How the task ended, in words and in the colour that state has everywhere in the app.
    func outcome(now: Date = .now) -> (text: String, color: Color) {
        if isRemoved { return ("Odstraněno po závazku", Theme.red) }
        switch status {
        case .completed, .completedLate:
            let late = status == .completedLate
            if isPartial {
                return ("Splněno částečně · \(Int((completionShare * 100).rounded())) %\(late ? " · pozdě" : "")", Theme.orange)
            }
            return late ? ("Splněno pozdě", Theme.orange) : ("Splněno včas", Theme.green)
        case .skipped: return ("Přeskočeno", Theme.red)
        case .failed: return ("Nesplněno", Theme.red)
        case .pending:
            return isMissed(now) ? ("Nesplněno · nevysvětleno", Theme.red) : ("Otevřené", Theme.textSecondary)
        }
    }
}
