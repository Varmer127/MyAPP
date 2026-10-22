import Foundation
import SwiftData
import Testing
@testable import Kept

@MainActor
struct PlanTests {
    private func plan(with tasks: [TaskItem], in context: ModelContext) -> WeeklyPlan {
        let plan = WeeklyPlan(weekStart: Fixture.now.weekStart)
        context.insert(plan)
        for task in tasks {
            task.plan = plan
            context.insert(task)
        }
        return plan
    }

    @Test func onlyOpenTasksOnDaysNotYetOverCanBePledged() throws {
        let context = try Fixture.context()
        let plan = plan(with: [
            Fixture.task("Dnes hotovo", day: 0, done: true),
            Fixture.task("Včera otevřeno", day: -1),
            Fixture.task("Zítra", day: 1),
            Fixture.task("Pozítří", day: 2),
        ], in: context)
        #expect(Set(plan.pledgeableTasks(Fixture.now).map(\.title)) == ["Zítra", "Pozítří"])
    }

    @Test func committingFreezesTheOriginalPromise() throws {
        let context = try Fixture.context()
        let tomorrow = Fixture.task("Zítra", day: 1, weight: 3)
        let done = Fixture.task("Hotovo", day: 0, done: true)
        let plan = plan(with: [tomorrow, done], in: context)
        PlanService.commit(plan, at: Fixture.now)
        #expect(plan.isCommitted)
        #expect(tomorrow.isCommitted && tomorrow.originalWeight == 3)
        #expect(!done.isCommitted)
    }

    @Test func aPlanMadeAheadMustReachTheMinimum() throws {
        let context = try Fixture.context()
        let plan = plan(with: [Fixture.task(day: 1), Fixture.task(day: 2)], in: context)
        let monday = plan.weekStart.addingTimeInterval(8 * 3600)
        #expect(PlanService.missesMinimum(plan, minimum: 5, now: monday))
        // After Monday the minimum no longer applies: a week that is already running is sealed as it is.
        #expect(!PlanService.missesMinimum(plan, minimum: 5, now: Fixture.now))
    }

    @Test func aHandedInPlanIsSealedWhenItsHourRunsOut() throws {
        let context = try Fixture.context()
        let plan = plan(with: [Fixture.task(day: 1), Fixture.task(day: 2)], in: context)
        PlanService.submit(plan, at: Fixture.now.addingTimeInterval(-2 * 3600))
        PlanService.sealDue([plan], minimum: 1, now: Fixture.now)
        #expect(plan.isCommitted)
    }

    @Test func anEmptiedPlanGoesBackToBeingADraft() throws {
        let context = try Fixture.context()
        let plan = plan(with: [], in: context)
        PlanService.submit(plan, at: Fixture.now.addingTimeInterval(-2 * 3600))
        PlanService.sealDue([plan], minimum: 1, now: Fixture.now)
        #expect(!plan.isCommitted)
        #expect(plan.submittedAt == nil)
    }

    @Test func aPlanIsNotSealedBeforeItsHourIsOver() throws {
        let context = try Fixture.context()
        let plan = plan(with: [Fixture.task(day: 1)], in: context)
        PlanService.submit(plan, at: Fixture.now.addingTimeInterval(-30 * 60))
        PlanService.sealDue([plan], minimum: 1, now: Fixture.now)
        #expect(!plan.isCommitted)
        #expect(plan.isSealing)
    }

    @Test func removingADraftTaskDeletesItButACommittedOneStaysAsABrokenPromise() throws {
        let context = try Fixture.context()
        let draft = Fixture.task("Návrh", day: 1)
        let sealed = Fixture.task("Slib", day: 2)
        let plan = plan(with: [draft, sealed], in: context)
        sealed.isCommitted = true
        PlanService.remove(draft, in: context, at: Fixture.now)
        PlanService.remove(sealed, in: context, at: Fixture.now)
        let left = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(left.map(\.title) == ["Slib"])
        #expect(left.first?.isRemoved == true)
        _ = plan
    }
}
