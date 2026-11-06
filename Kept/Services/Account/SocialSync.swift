import SwiftData
import SwiftUI

/// Sends the numbers of this week (and, early in a week, of the last one) to the server, so friends and
/// leaderboards are up to date. Runs only with an account; waits a moment after changes so a burst of taps is one upload.
struct SocialSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
    @Query private var diary: [DiaryEntry]
    @Query private var settingsList: [UserSettings]
    private let account = AccountService.shared

    /// What changes the shared numbers: how many tasks there are and how many are closed.
    private var fingerprint: String {
        let closed = tasks.filter { $0.status != .pending }.count
        return "\(tasks.count)-\(closed)-\(plans.filter(\.isCommitted).count)-\(account.profile?.shareLevel.rawValue ?? "-")"
    }

    func body(content: Content) -> some View {
        content
            .task(id: "\(fingerprint)-\(scenePhase == .active)") {
                guard scenePhase == .active, let profile = account.profile else { return }
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await upload(includePlan: profile.shareLevel == .plan)
            }
    }

    private func upload(includePlan: Bool) async {
        let now = Date.now
        let streak = ScoreEngine.dayStreak(tasks, now: now)
        let badges = ProfileData.badges(tasks: tasks, plans: plans, failures: failures, diary: diary,
                                        settings: settingsList.first).filter(\.isEarned).count
        var weeks = [now.weekStart]
        // The first two days of a week also finish the numbers of the week before.
        if now.timeIntervalSince(now.weekStart) < 2 * 86_400 { weeks.append(now.weekStart.addingDays(-7)) }
        for week in weeks {
            let snapshot = WeekSnapshot.make(week: week, tasks: tasks, plans: plans, streak: streak, badges: badges,
                                             includePlan: includePlan, now: now)
            try? await FriendsService.shared.push(snapshot)
        }
        await TogetherService.shared.reload()
        await TogetherService.shared.push(tasks: tasks, now: now)
    }
}
