import Foundation

extension String {
    var urlPathSegmentEncoded: String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")

        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
