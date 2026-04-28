//
//  CreateLineCheckRequest.swift
//  tml.2.0
//
//  Created by mike on 4/28/26.
//
struct CreateLineCheckRequest: Codable {
    let userId: String
    let stationIds: [String]
}
