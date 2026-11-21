import Foundation

public enum EmergencyShortcut {
    public static let keyCode: Int64 = 32 // U

    public static func matches(control: Bool, command: Bool, keyCode: Int64) -> Bool {
        control && command && keyCode == Self.keyCode
    }
}
