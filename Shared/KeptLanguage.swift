import Foundation
import ObjectiveC

/// The language chosen in the app. It is kept in the app group, so the widgets speak it too,
/// and texts are looked up in its translations at once, without leaving for the iPhone settings.
enum KeptLanguage {
    static let storageKey = "appLanguage"
    static let codes = ["cs", "en"]

    private static var group: UserDefaults? { UserDefaults(suiteName: WidgetSnapshot.appGroup) }

    /// The language picked in the app, or nil when none has been picked yet.
    static var chosen: String? {
        let code = group?.string(forKey: storageKey) ?? UserDefaults.standard.string(forKey: storageKey)
        return code.flatMap { codes.contains($0) ? $0 : nil }
    }

    static func save(_ code: String) {
        group?.set(code, forKey: storageKey)
        UserDefaults.standard.set(code, forKey: storageKey)
        // The next launch and the system's own texts (permission prompts and the like) follow too.
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
    }

    /// Called once at launch, before anything is shown. In the app `code` is fixed and changed with `use`;
    /// the widgets pass nil and read the app's choice whenever they draw.
    static func install(code: String?) {
        LanguageBundle.bundles = Dictionary(uniqueKeysWithValues: codes.compactMap { code in
            Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)).map { (code, $0) }
        })
        LanguageBundle.fixedCode = code
        object_setClass(Bundle.main, LanguageBundle.self)
    }

    static func use(_ code: String) {
        LanguageBundle.fixedCode = code
    }
}

/// The main bundle, answering text lookups from the chosen language's translations.
final class LanguageBundle: Bundle, @unchecked Sendable {
    /// Filled once at launch and only read afterwards.
    nonisolated(unsafe) static var bundles: [String: Bundle] = [:]
    nonisolated(unsafe) static var fixedCode: String?

    static var code: String? { fixedCode ?? KeptLanguage.chosen }
    static var translations: Bundle? { code.flatMap { bundles[$0] } }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let translations = Self.translations {
            return translations.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    @available(iOS 18.4, *)
    override func __localizedString(forKey key: String, value: String?, table tableName: String?,
                                    localizations: [String]) -> String {
        if let translations = Self.translations {
            return translations.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.__localizedString(forKey: key, value: value, table: tableName, localizations: localizations)
    }

    override var preferredLocalizations: [String] {
        Self.code.map { [$0] } ?? super.preferredLocalizations
    }
}

extension Bundle {
    /// Where texts put together in code with `String(localized:)` are looked up: the chosen language.
    static var kept: Bundle { LanguageBundle.translations ?? .main }
}
