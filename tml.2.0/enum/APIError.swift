//
//  APIError.swift
//  tml.2.0
//
//  Created by mike on 4/28/26.
//

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case serverError(Int)
}
