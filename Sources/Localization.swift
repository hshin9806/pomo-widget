import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ argument: CVarArg) -> String {
    String(format: NSLocalizedString(key, comment: ""), argument)
}
