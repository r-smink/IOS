import Foundation

extension String {
    var hhmm: String {
        if count >= 5 { return String(prefix(5)) }
        return self
    }
}
