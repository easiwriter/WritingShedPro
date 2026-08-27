import Foundation
import Observation
import UIKit

struct DocumentSpellingIssue: Identifiable, Equatable, Sendable {
    let id: UUID
    let word: String
    var range: NSRange

    init(id: UUID = UUID(), word: String, range: NSRange) {
        self.id = id
        self.word = word
        self.range = range
    }
}

@MainActor
@Observable
final class DocumentSpellingManager {
    private(set) var issues: [DocumentSpellingIssue] = []
    private(set) var currentIndex = 0
    private(set) var suggestions: [String] = []
    private(set) var isScanning = false
    var selectedLanguage: String

    @ObservationIgnored private weak var textView: UITextView?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var ignoredWords: Set<String> = []
    @ObservationIgnored private var textChangeObserver: NSObjectProtocol?
    @ObservationIgnored private var highlightViews: [UIView] = []

    private let issueHighlightColor = UIColor.systemRed.withAlphaComponent(0.16)
    private let currentIssueHighlightColor = UIColor.systemOrange.withAlphaComponent(0.32)
    private let currentIssueUnderlineColor = UIColor.systemRed.withAlphaComponent(0.9)

    init(language: String? = nil) {
        selectedLanguage = language ?? Self.defaultLanguage
    }

    deinit {
        scanTask?.cancel()
        if let textChangeObserver {
            NotificationCenter.default.removeObserver(textChangeObserver)
        }
    }

    nonisolated static var availableLanguages: [String] {
        UITextChecker.availableLanguages.sorted { lhs, rhs in
            let lhsName = Locale.current.localizedString(forIdentifier: lhs) ?? lhs
            let rhsName = Locale.current.localizedString(forIdentifier: rhs) ?? rhs
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }

    nonisolated static var defaultLanguage: String {
        let available = UITextChecker.availableLanguages
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        if available.contains(preferred) {
            return preferred
        }

        let normalizedPreferred = preferred.replacingOccurrences(of: "-", with: "_")
        if available.contains(normalizedPreferred) {
            return normalizedPreferred
        }

        let languageCode = Locale(identifier: preferred).language.languageCode?.identifier
        if let match = available.first(where: {
            Locale(identifier: $0).language.languageCode?.identifier == languageCode
        }) {
            return match
        }

        return available.first ?? "en_GB"
    }

    var currentIssue: DocumentSpellingIssue? {
        guard issues.indices.contains(currentIndex) else { return nil }
        return issues[currentIndex]
    }

    var issueCountText: String {
        guard !issues.isEmpty else { return "0 of 0" }
        return "\(currentIndex + 1) of \(issues.count)"
    }

    func connect(to textView: UITextView) {
        clearHighlights()
        if let textChangeObserver {
            NotificationCenter.default.removeObserver(textChangeObserver)
        }
        self.textView = textView
        textChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self, weak textView] _ in
            Task { @MainActor in
                guard let self, let textView else { return }
                self.scan(text: textView.text, startingAt: textView.selectedRange.location)
            }
        }
    }

    func disconnect() {
        if let textChangeObserver {
            NotificationCenter.default.removeObserver(textChangeObserver)
            self.textChangeObserver = nil
        }
        scanTask?.cancel()
        scanTask = nil
        clearHighlights()
        textView = nil
        issues = []
        suggestions = []
        currentIndex = 0
        isScanning = false
    }

    func scan(text: String, startingAt location: Int = 0) {
        scanTask?.cancel()
        clearHighlights()
        isScanning = true
        let language = selectedLanguage
        let ignoredWords = ignoredWords

        scanTask = Task { [weak self] in
            let foundIssues = await Task.detached(priority: .userInitiated) {
                Self.findIssues(in: text, language: language, ignoring: ignoredWords)
            }.value
            guard !Task.isCancelled, let self else { return }

            issues = foundIssues
            if let nearestIndex = issues.firstIndex(where: { $0.range.location >= location }) {
                currentIndex = nearestIndex
            } else {
                currentIndex = issues.isEmpty ? 0 : issues.count - 1
            }
            isScanning = false
            refreshCurrentIssue()
        }
    }

    func nextIssue() {
        guard !issues.isEmpty else { return }
        currentIndex = (currentIndex + 1) % issues.count
        refreshCurrentIssue()
    }

    func previousIssue() {
        guard !issues.isEmpty else { return }
        currentIndex = (currentIndex - 1 + issues.count) % issues.count
        refreshCurrentIssue()
    }

    func ignoreCurrentIssue() {
        removeCurrentIssue()
    }

    func ignoreAllOccurrencesOfCurrentWord() {
        guard let currentIssue else { return }
        let normalizedWord = currentIssue.word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        ignoredWords.insert(normalizedWord)
        issues.removeAll {
            $0.word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedWord
        }
        currentIndex = min(currentIndex, max(issues.count - 1, 0))
        refreshCurrentIssue()
    }

    func didReplaceCurrentIssue(with replacement: String) {
        guard currentIssue != nil else { return }
        issues = Self.issuesAfterReplacing(
            issues,
            at: currentIndex,
            replacementUTF16Length: (replacement as NSString).length
        )
        currentIndex = min(currentIndex, max(issues.count - 1, 0))
        refreshCurrentIssue()
    }

    private func removeCurrentIssue() {
        guard issues.indices.contains(currentIndex) else { return }
        issues.remove(at: currentIndex)
        currentIndex = min(currentIndex, max(issues.count - 1, 0))
        refreshCurrentIssue()
    }

    private func refreshCurrentIssue() {
        guard let currentIssue else {
            suggestions = []
            updateHighlights()
            return
        }

        let checker = UITextChecker()
        let sourceText = textView?.text ?? currentIssue.word
        let suggestionRange = textView == nil
            ? NSRange(location: 0, length: (currentIssue.word as NSString).length)
            : currentIssue.range
        suggestions = checker.guesses(
            forWordRange: suggestionRange,
            in: sourceText,
            language: selectedLanguage
        ) ?? []
        updateHighlights()
        selectCurrentIssue()
    }

    private func updateHighlights() {
        guard let textView else { return }

        let layoutManager = textView.layoutManager
        clearHighlights()
        layoutManager.ensureLayout(for: textView.textContainer)

        let maxHighlights = 500
        let shouldLimitHighlights = issues.count > maxHighlights
        for (index, issue) in issues.enumerated() {
            let isCurrent = index == currentIndex
            guard isCurrent || !shouldLimitHighlights || index < maxHighlights,
                  NSMaxRange(issue.range) <= textView.textStorage.length else { continue }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: issue.range,
                actualCharacterRange: nil
            )
            let glyphBounds = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textView.textContainer
            )
            guard !glyphBounds.isNull, !glyphBounds.isEmpty else { continue }

            let highlightView = UIView(
                frame: glyphBounds.offsetBy(
                    dx: textView.textContainerInset.left,
                    dy: textView.textContainerInset.top
                )
            )
            highlightView.isUserInteractionEnabled = false
            highlightView.backgroundColor = isCurrent ? currentIssueHighlightColor : issueHighlightColor
            highlightView.layer.cornerRadius = 2
            if isCurrent {
                highlightView.layer.borderColor = currentIssueUnderlineColor.cgColor
                highlightView.layer.borderWidth = 1.5
            }
            textView.addSubview(highlightView)
            highlightViews.append(highlightView)
        }
    }

    private func clearHighlights() {
        highlightViews.forEach { $0.removeFromSuperview() }
        highlightViews.removeAll()
    }

    private func selectCurrentIssue() {
        guard let issue = currentIssue,
              let textView,
              NSMaxRange(issue.range) <= textView.textStorage.length else { return }
        textView.scrollRangeToVisible(issue.range)
    }

    nonisolated static func findIssues(
        in text: String,
        language: String,
        ignoring ignoredWords: Set<String> = []
    ) -> [DocumentSpellingIssue] {
        guard !text.isEmpty else { return [] }

        let checker = UITextChecker()
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var location = 0
        var results: [DocumentSpellingIssue] = []

        while location < fullRange.length {
            let misspelledRange = checker.rangeOfMisspelledWord(
                in: text,
                range: fullRange,
                startingAt: location,
                wrap: false,
                language: language
            )
            guard misspelledRange.location != NSNotFound,
                  misspelledRange.length > 0 else { break }

            let word = nsText.substring(with: misspelledRange)
            let normalizedWord = word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if !ignoredWords.contains(normalizedWord) {
                results.append(DocumentSpellingIssue(word: word, range: misspelledRange))
            }
            location = max(NSMaxRange(misspelledRange), location + 1)
        }

        return results
    }

    nonisolated static func issuesAfterReplacing(
        _ issues: [DocumentSpellingIssue],
        at replacedIndex: Int,
        replacementUTF16Length: Int
    ) -> [DocumentSpellingIssue] {
        guard issues.indices.contains(replacedIndex) else { return issues }

        var adjustedIssues = issues
        let replacedIssue = adjustedIssues.remove(at: replacedIndex)
        let delta = replacementUTF16Length - replacedIssue.range.length
        for index in adjustedIssues.indices where adjustedIssues[index].range.location > replacedIssue.range.location {
            adjustedIssues[index].range.location += delta
        }
        return adjustedIssues
    }
}