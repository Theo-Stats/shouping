import Foundation

enum ExitPasswordGenerator {
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")

    static func make(length: Int = 16) -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<max(length, 8)).map { _ in
            characters.randomElement(using: &generator)!
        })
    }

    static func sharingText(for password: String, generatedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let timestamp = formatter.string(from: generatedAt)

        return """
        守屏应用密码
        密码：\(password)
        生成时间：\(timestamp)
        """
    }
}
