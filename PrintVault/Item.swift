//
//  Item.swift
//  PrintVault
//
//  Created by Riru on 26/12/25.
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
