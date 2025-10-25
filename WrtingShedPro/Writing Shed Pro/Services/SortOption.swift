import Foundation

/// Generic helper struct for sort options
struct SortOption<T: Hashable> {
    let order: T
    let title: String
    
    init(_ order: T, title: String) {
        self.order = order
        self.title = title
    }
}