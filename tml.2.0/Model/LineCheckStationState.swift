//
//  LineCheckStationState.swift
//  tml.2.0
//
//  Created by mike on 5/6/26.
//

import Foundation

struct LineCheckStationState: Identifiable, Equatable {

    let id: UUID
    let stationName: String

    var items: [LineCheckItemState]
}
