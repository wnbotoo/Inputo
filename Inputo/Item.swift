//
//  Item.swift
//  Inputo
//
//  Created by Wenbo Tu on 6/11/26.
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
