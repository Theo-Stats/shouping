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
        let timestamp = generatedAt.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "zh_CN"))
        )

        return """
        守屏（首屏）退出密码
        密码：\(password)
        生成时间：\(timestamp)
        用途：在守屏进入专注后，暂停或跳过本次限制时使用。
        使用要求：只有当你确实需要暂停或跳过时，才请保密人把密码告诉你。
        """
    }
}
