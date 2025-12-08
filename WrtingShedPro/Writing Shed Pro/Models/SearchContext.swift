import SwiftUI
import Observation

/// Environment object to pass search context from multi-file search to file editor
@Observable
class SearchContext {
    var searchText: String = ""
    var replaceText: String? = nil
    var isCaseSensitive: Bool = false
    var isWholeWord: Bool = false
    var isRegex: Bool = false
    var shouldActivate: Bool = false
    var isFromMultiFileSearch: Bool = false  // If true, show simplified replace-only UI
    
    init() {}
    
    init(searchText: String, replaceText: String?, isCaseSensitive: Bool, isWholeWord: Bool, isRegex: Bool) {
        self.searchText = searchText
        self.replaceText = replaceText
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWord = isWholeWord
        self.isRegex = isRegex
        self.shouldActivate = true
        self.isFromMultiFileSearch = true
    }
    
    func reset() {
        searchText = ""
        replaceText = nil
        isCaseSensitive = false
        isWholeWord = false
        isRegex = false
        shouldActivate = false
        isFromMultiFileSearch = false
    }
}
