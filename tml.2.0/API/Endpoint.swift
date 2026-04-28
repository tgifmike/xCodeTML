//
//  Endpoint.swift
//  tml.2.0
//
//  Created by mike on 4/28/26.
//

import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
}

struct Endpoint {

    let path: String
        let method: HTTPMethod
        let body: Encodable?

    var url: URL? {
        URL(string: "\(Config.baseURL)\(path)")
    }

    static func getLocations(userId: String) -> Endpoint {
        Endpoint(
            path: "/user-access-locations/\(userId)/locations",
            method: .GET,
            body: nil
        )
    }

    static func getAccounts(userId: String) -> Endpoint {
        Endpoint(
            path: "/user-access/\(userId)/accounts",
            method: .GET,
            body: nil
        )
    }

    static func createLineCheck(userId: String, stationIds: [String]) -> Endpoint {
        Endpoint(
            path: "/line-checks/create?userId=\(userId)",
            method: .POST,
            body: stationIds
        )
    }
    static func getLocationsForAccount(accountId: String) -> Endpoint {
            Endpoint(
                path: "/locations/accounts/\(accountId)/locations",
                method: .GET,
                body: nil
            )
        }

        static func getLocationsForUser(userId: String) -> Endpoint {
            Endpoint(
                path: "/user-access-locations/\(userId)/locations",
                method: .GET,
                body: nil
            )
        }
    static func deleteUser(userId: String) -> Endpoint {
            Endpoint(
                path: "/users/delete/\(userId)",
                method: .DELETE,
                body: nil
            )
        }
    static func getStationsByLocation(locationId: String) -> Endpoint {
            Endpoint(
                path: "/stations/by-location/\(locationId)",
                method: .GET,
                body: nil
            )
        }

        static func getLineCheckById(lineCheckId: String) -> Endpoint {
            Endpoint(
                path: "/line-checks/\(lineCheckId)",
                method: .GET,
                body: nil
            )
        }

        static func saveLineCheck(_ dto: LineCheckDto) -> Endpoint {
            Endpoint(
                path: "/line-checks/save",
                method: .POST,
                body: dto
            )
        }
}

extension Encodable {
    func toData() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
