//
//  Item.swift
//  WSP Reader
//
//  Created by Keith Lander on 25/01/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
