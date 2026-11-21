import CryptoKit
import Foundation
import Security

enum ExitPasswordStoreError: LocalizedError {
    case passwordTooShort
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .passwordTooShort:
            return "密码至少需要 4 个字符。"
        case .keychain(let status):
            return "无法存取退出密码（Keychain 错误 \(status)）。"
        }
    }
}

final class ExitPasswordStore {
    private struct Record: Codable {
        let salt: Data
        let digest: Data
        let rounds: UInt32
    }

    private let service = "com.example.shouping"
    private let account = "focus-exit-password"

    var hasPassword: Bool {
        (try? loadRecord()) != nil
    }

    func setPassword(_ password: String) throws {
        guard password.count >= 4 else { throw ExitPasswordStoreError.passwordTooShort }

        var salt = Data(count: 16)
        let randomStatus = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw ExitPasswordStoreError.keychain(randomStatus)
        }

        let rounds: UInt32 = 60_000
        let record = Record(
            salt: salt,
            digest: derive(password: password, salt: salt, rounds: rounds),
            rounds: rounds
        )
        let data = try JSONEncoder().encode(record)
        let query = baseQuery
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ExitPasswordStoreError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw ExitPasswordStoreError.keychain(updateStatus)
        }
    }

    func verify(_ password: String) -> Bool {
        guard let record = try? loadRecord() else { return false }
        let candidate = derive(password: password, salt: record.salt, rounds: record.rounds)
        return constantTimeEqual(candidate, record.digest)
    }

    func removePassword() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ExitPasswordStoreError.keychain(status)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }

    private func loadRecord() throws -> Record {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            throw ExitPasswordStoreError.keychain(status)
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw ExitPasswordStoreError.keychain(status)
        }
        return try JSONDecoder().decode(Record.self, from: data)
    }

    private func derive(password: String, salt: Data, rounds: UInt32) -> Data {
        let passwordData = Data(password.utf8)
        var digest = Data(SHA256.hash(data: passwordData + salt))
        guard rounds > 1 else { return digest }
        for _ in 1..<rounds {
            digest = Data(SHA256.hash(data: digest + salt))
        }
        return digest
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}
