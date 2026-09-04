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
    case pinFailed(String?, Date?)
    case locked(String?, Date?, Int?)
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
        case .pinFailed(let message, let nextLockoutUntil):
            if let nextLockoutUntil {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                return "\(message ?? "PIN not recognized.") Next wrong entry will lock this user until \(formatter.string(from: nextLockoutUntil))."
            }

            return message ?? "PIN not recognized."
        case .locked(let message, let lockedUntil, let retryAfterSeconds):
            if let lockedUntil {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                return "PIN locked until \(formatter.string(from: lockedUntil))."
            }

            if let retryAfterSeconds {
                let minutes = max(1, Int(ceil(Double(retryAfterSeconds) / 60.0)))
                let label = minutes == 1 ? "minute" : "minutes"
                return "PIN locked for about \(minutes) \(label)."
            }

            return message ?? "PIN locked."
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
