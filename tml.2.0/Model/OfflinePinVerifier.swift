import Argon2Swift
import Foundation

enum OfflinePinVerifier {
    static func verify(pin: String, phcString: String) throws -> Bool {
        try Argon2Swift.verifyHashString(
            password: pin,
            hash: phcString,
            type: .id
        )
    }
}

enum OfflinePinVerifierError: LocalizedError {
    case argon2PackageUnavailable

    var errorDescription: String? {
        switch self {
        case .argon2PackageUnavailable:
            return "Offline PIN verification needs the Argon2 Swift package linked to the app target. Online PIN login can still work."
        }
    }
}
