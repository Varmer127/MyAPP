import SwiftUI
import SwiftData

extension WeekView {
    var openTaskIDs: Set<UUID> { Set((plan?.activeTasks ?? []).filter { $0.status == .pending }.map(\.uid)) }

    var isPresenting: Bool { showsQuickPlan || editor != nil || planToCommit != nil || detailTask != nil }

    /// The draft's tasks that a fresh start clears: open ones that are not done yet.
    var resettableTasks: [TaskItem] {
        guard canCopyWeek, let plan else { return [] }
        return plan.activeTasks.filter { $0.status == .pending && $0.scheduledDate.endOfDay > Date.now }
    }

    func resetPlan() {
        withAnimation {
            for task in resettableTasks { PlanService.remove(task, in: context) }
        }
        Persistence.save(context)
        rememberTasks()
    }

    func rememberTasks() {
        knownTaskIDs = openTaskIDs
        knownWeekStart = weekStart
    }

    /// Sends every task planned since the last look into the send button, one after another.
    func launchFlights() {
        guard knownWeekStart == weekStart else { return rememberTasks() }
        guard !isPresenting else { return }
        let added = openTaskIDs.subtracting(knownTaskIDs)
        knownTaskIDs = openTaskIDs
        guard !added.isEmpty else { return }
        fly(added, attempt: 0)
    }

    /// In an empty week the send button only appears with the first task, so wait for it a moment.
    func fly(_ added: Set<UUID>, attempt: Int) {
        guard canCommit, let target = flightFrames.frames[FlightFramesKey.commitButton] else {
            guard attempt < 5 else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.12))
                fly(added, attempt: attempt + 1)
            }
            return
        }
        let newTasks = (plan?.activeTasks ?? []).filter { added.contains($0.uid) }.sorted { $0.dueDate < $1.dueDate }
        let screen = UIScreen.main.bounds
        let fallback = CGPoint(x: screen.midX, y: screen.height * 0.4)
        let stagger = 0.07
        let shown = Array(newTasks.prefix(12))
        if !reduceMotion {
            let launched = shown.enumerated().map { index, task -> PlanFlight in
                let row = flightFrames.frames[task.uid.uuidString]
                let start = flightOrigin
                    ?? row.flatMap { screen.intersects($0) ? CGPoint(x: $0.minX + 34, y: $0.midY) : nil }
                    ?? fallback
                return PlanFlight(icon: task.icon, from: start, to: CGPoint(x: target.midX, y: target.midY),
                                  delay: Double(index) * stagger)
            }
            flights.append(contentsOf: launched)
        }
        flightOrigin = nil
        let landing = reduceMotion ? 0 : PlanFlight.duration + Double(shown.count - 1) * stagger
        let ids = Set(flights.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(landing))
            withAnimation(.spring(duration: 0.3)) {
                commitPulse += 1
                landedCount = newTasks.count
            }
            flights.removeAll { ids.contains($0.id) }
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(duration: 0.4)) { commitPulse += 1 }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) { landedCount = 0 }
        }
    }
}
