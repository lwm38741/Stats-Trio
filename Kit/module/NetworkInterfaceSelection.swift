import Foundation

public enum NetworkInterfaceSelection {
    public static func resolve(requested: String?, primary: String, isPresent: (String) -> Bool) -> String {
        guard let requested, !requested.isEmpty, isPresent(requested) else { return primary }
        return requested
    }
}
