//
//  LineCheckStationVM.swift
//  tml.2.0
//
//  Created by mike on 5/6/26.
//

import Foundation
import Combine

@MainActor
final class LineCheckStationVM: ObservableObject, Identifiable {

    let id: UUID
    let stationName: String

    @Published var rows: [LineCheckItemRowVM]

    init(input: LineCheckStationInput) {
        self.id = input.id
        self.stationName = input.stationName
        self.rows = input.items.map { LineCheckItemRowVM(input: $0) }
    }

    func toInput() -> LineCheckStationInput {
        LineCheckStationInput(
            id: id,
            stationName: stationName,
            items: rows.map { $0.toInput() }
        )
    }
}
