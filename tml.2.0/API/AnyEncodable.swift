//
//  AnyEncodable.swift
//  tml.2.0
//
//  Created by mike on 4/28/26.
//

import Foundation

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeFunc = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

extension Encodable {
    func toDictionary() -> [String: Any] {
        let data = try? JSONEncoder().encode(self)
        let json = try? JSONSerialization.jsonObject(with: data ?? Data())
        return json as? [String: Any] ?? [:]
    }
}
