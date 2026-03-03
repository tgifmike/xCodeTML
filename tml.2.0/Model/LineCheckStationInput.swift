//
//  LineCheckStationInput.swift
//  tml.2.0
//
//  Created by mike on 3/3/26.
//
import Foundation

struct LineCheckStationInput: Identifiable {
    let id: UUID
    var stationName: String
    var items: [LineCheckItemInput]
}
