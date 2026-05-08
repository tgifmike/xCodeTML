//
//  LineCheckItemState.swift
//  tml.2.0
//
//  Created by mike on 5/6/26.
//

import Foundation

struct LineCheckItemState: Identifiable, Equatable {

    let id: UUID

    // MARK: Station Info
    let stationId: UUID
    let stationName: String

    // MARK: Item DTO
    let item: LineCheckItemDto

    // MARK: Editable State
    var temperature: String
    var observations: String
    var isChecked: Bool?
    var isMissing: Bool
}
