import Foundation
import Testing
@testable import Kept

struct NotificationCopyTests {
    /// A banner shows two lines; a message longer than that is cut off mid-thought.
    @Test func gentleAndStrictMessagesFitABanner() {
        for template in NotificationTemplates.gentleAndStrict {
            let filled = template
                .replacingOccurrences(of: "{time}", with: "17:30")
                .replacingOccurrences(of: "{why}", with: "Chci mluvit plynule")
                .replacingOccurrences(of: "{n}", with: "12")
                .replacingOccurrences(of: "{days}", with: "14 dní")
            #expect(filled.count <= NotificationManager.bannerLength, "Too long for a banner: \(filled)")
            #expect(!filled.contains("{"), "Unknown placeholder: \(filled)")
        }
    }

    /// The task's name is the title, so Normal and Strict bodies never have to decline it.
    @Test func gentleAndStrictBodiesDoNotBendTheTaskName() {
        for template in NotificationTemplates.gentleAndStrict {
            #expect(!template.contains("{task}"), "Names the task in the body: \(template)")
        }
    }

    /// Under a savage headline the title says nothing about the task, so the body has to.
    @Test func savageHeadlineBodyNamesTheTask() {
        for seed in 0..<40 {
            let body = NotificationTemplates.taskMessage(level: 3, title: "Angličtina", time: "17:30", why: "",
                                                         failures: 0, seed: seed, namesTask: true)
            #expect(body.contains("Angličtina"), "No task in: \(body)")
        }
    }

    /// Social titles read naturally for anyone: no "přijal(a)" style forms.
    @Test func socialTitlesAvoidSlashForms() {
        let kinds: [AppNotification.Kind] = [.friendRequest, .friendAccepted, .poke, .reaction, .betInvite, .betClaim,
                                             .betResult, .challengeInvite, .groupInvite, .activityInvite, .buddyRequest,
                                             .buddyAccepted, .witnessRequest, .witnessAnswer]
        for kind in kinds {
            let note = AppNotification(id: UUID(), kind: kind, actorId: nil, actorName: "Irena", ref: nil, body: nil,
                                       createdAt: .now, seen: false)
            #expect(!note.title.contains("(a)"), "\(kind): \(note.title)")
        }
    }
}
