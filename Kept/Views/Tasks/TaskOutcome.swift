import SwiftUI

extension TaskItem {
    /// How the task ended, in words and in the colour that state has everywhere in the app.
    func outcome(now: Date = .now) -> (text: String, color: Color) {
        if isRemoved { return (String(localized: "Odstraněno po závazku", bundle: .kept), Theme.red) }
        switch status {
        case .completed, .completedLate:
            let late = status == .completedLate
            if isPartial {
                let percent = Int((completionShare * 100).rounded())
                return (late ? String(localized: "Splněno částečně · \(percent) % · pozdě", bundle: .kept) : String(localized: "Splněno částečně · \(percent) %", bundle: .kept),
                        Theme.orange)
            }
            return late ? (String(localized: "Splněno pozdě", bundle: .kept), Theme.orange) : (String(localized: "Splněno včas", bundle: .kept), Theme.green)
        case .excused: return (String(localized: "Zrušeno za body · bez postihu", bundle: .kept), Theme.textSecondary)
        case .skipped: return (String(localized: "Přeskočeno", bundle: .kept), Theme.red)
        case .failed: return (String(localized: "Nesplněno", bundle: .kept), Theme.red)
        case .pending:
            return isMissed(now) ? (String(localized: "Nesplněno · nevysvětleno", bundle: .kept), Theme.red) : (String(localized: "Otevřené", bundle: .kept), Theme.textSecondary)
        }
    }
}
