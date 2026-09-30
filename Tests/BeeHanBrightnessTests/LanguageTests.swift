import Foundation
import Testing
@testable import BeeHanBrightness

private func placeholders(_ text: String) -> Set<String> {
    Set(text.matches(of: #/\{[a-z]+\}/#).map { String($0.output) })
}

@Test func everyLanguageHasEveryString() {
    for language in Language.allCases {
        let keys = Set((Strings.all[language] ?? [:]).keys)
        #expect(keys == Set(Strings.en.keys), "\(language.rawValue): \(keys.symmetricDifference(Strings.en.keys).sorted())")
    }
}

// A translation that drops or misspells {version} would show the braces, or lose the number.
@Test func everyTranslationKeepsItsPlaceholders() {
    for language in Language.allCases {
        for (key, text) in Strings.all[language] ?? [:] {
            #expect(placeholders(text) == placeholders(Strings.en[key] ?? ""), "\(language.rawValue) \(key): \(text)")
        }
    }
}

@Test func missingStringsFallBackToEnglishThenTheKey() {
    #expect(tr("quit", in: .de) == "BeeHan Brightness beenden")
    #expect(tr("not_a_key", in: .de) == "not_a_key")
    #expect(tr("version", ["version": "1.2.3"], in: .fr) == "Version 1.2.3")
}

@Test func everyLanguageHasANameAndAFlag() {
    #expect(Language.allCases.count == 12)
    #expect(Set(Language.allCases.map(\.name)).count == 12 && Set(Language.allCases.map(\.flag)).count == 12)
    #expect(Language.pt.flag == "🇧🇷")
}
