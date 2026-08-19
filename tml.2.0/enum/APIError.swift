//
//  APIError.swift
//  tml.2.0
//
//  Created by mike on 4/28/26.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized(String?)
    case forbidden(String?)
    case serverError(Int, String?)
    case uploadContractMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unauthorized(let message):
            return message ?? "You are not authorized. Please sign in again."
        case .forbidden(let message):
            return message ?? "You do not have permission to perform this action."
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Server error \(statusCode): \(message)"
            }

            return "Server error \(statusCode)."
        case .uploadContractMismatch(let message):
            return message
        }
    }
}
