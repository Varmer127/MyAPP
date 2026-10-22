import Foundation
import SwiftData

/// The one data store of the app, shared by the UI and by actions that arrive while no screen is open
/// (the widget's "done" button).
/// The first version of the data model. When a model changes in a way automatic migration cannot handle,
/// this version is frozen as it was and a new one is added with a migration stage between them.
enum KeptSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [TaskItem.self, WeeklyPlan.self, CommitmentEdit.self, FailureRecord.self, FocusSession.self, ExerciseLog.self,
         SetLog.self, Postponement.self, WeekReflection.self, PointsPurchase.self, BodyEntry.self, DiaryEntry.self,
         FutureLetter.self, UserSettings.self]
    }
}

enum KeptMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [KeptSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
enum AppStore {
    static let container: ModelContainer = makeContainer()

    /// Set when the data could not be opened and a fresh store had to be started; the app tells the user once.
    static let recoveryKey = "storeRecoveryMessage"

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: KeptSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: KeptMigrationPlan.self, configurations: configuration)
            excludeAttachmentsFromBackup(near: configuration.url)
            return container
        } catch {
            // A store that cannot be opened must never take the app down with it: the broken files are put aside
            // untouched and the app starts clean. Nothing is deleted, so the data can still be recovered by hand.
            let folder = putAside(configuration.url)
            UserDefaults.standard.set(folder?.lastPathComponent ?? "unknown", forKey: recoveryKey)
            if let fresh = try? ModelContainer(for: schema, migrationPlan: KeptMigrationPlan.self, configurations: configuration) {
                return fresh
            }
            // Last resort: keep the app usable for this run without touching the disk.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory store of known models cannot fail to open.
            return try! ModelContainer(for: schema, configurations: memory)
        }
    }

    /// Moves the store files into a dated folder next to them and returns that folder.
    private static func putAside(_ storeURL: URL) -> URL? {
        let fileManager = FileManager.default
        let directory = storeURL.deletingLastPathComponent()
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let folder = directory.appendingPathComponent("BrokenStore-\(stamp)", isDirectory: true)
        guard (try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return nil }
        let prefix = storeURL.lastPathComponent
        let names = ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasPrefix(prefix) || $0 == ".default_SUPPORT" }
        for name in names {
            try? fileManager.moveItem(at: directory.appendingPathComponent(name), to: folder.appendingPathComponent(name))
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var url = folder
        try? url.setResourceValues(values)
        return folder
    }

    /// Proof photos live in the store's attachment folder. Like the body photos, they stay out of device backups.
    private static func excludeAttachmentsFromBackup(near storeURL: URL) {
        var folder = storeURL.deletingLastPathComponent().appendingPathComponent(".default_SUPPORT", isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }

    /// Tasks the widget may complete with one tap: nothing that needs a proof photo or a workout log.
    nonisolated static func canCompleteFromWidget(_ task: TaskItem) -> Bool {
        task.status == .pending && !task.isRemoved && !task.requiresProof && task.category != .gym
    }

    static func completeFromWidget(_ id: String) async {
        let context = container.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        guard let task = tasks.first(where: { $0.uid.uuidString == id }), canCompleteFromWidget(task) else { return }
        task.markDone()
        Persistence.save(context)
        let plans = (try? context.fetch(FetchDescriptor<WeeklyPlan>())) ?? []
        if !FocusActivityManager.reconcile(tasks) {
            NotificationManager.cancelFocusEnd()
        }
        WidgetBridge.update(tasks: tasks, plans: plans, targets: UserSettings.current(in: context).weeklyTargets)
        await NotificationManager.reschedule(context: context)
    }
}
