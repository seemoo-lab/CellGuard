import Foundation
import Security

func writeAppToken(_ token: String) -> Bool {
    guard let config = readConfig() else {
        return false
    }

    // https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
    // https://developer.apple.com/documentation/BundleResources/Entitlements/keychain-access-groups
    let accessGroup = "\(config.developmentTeam).\(config.productBundleIdentifier)"

    // https://developer.apple.com/documentation/security/searching-for-keychain-items
    let service = "capture-packets-token"
    let searchQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccessGroup as String: accessGroup,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnData as String: false
    ]

    let status = SecItemCopyMatching(searchQuery as CFDictionary, nil)
    if status == errSecItemNotFound {
        // Add the new item

        // https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain
        // https://developer.apple.com/documentation/security/item-attribute-keys-and-values
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: token.data(using: .utf8)!
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        // https://developer.apple.com/documentation/security/security-framework-result-codes
        // https://developer.apple.com/documentation/security/errsecmissingentitlement
        guard status == errSecSuccess else {
            let res = SecCopyErrorMessageString(status, nil)
            print("Keychain Error while adding (\(status)) -> \(String(describing: res))")
            return false
        }

        print("Inserted token into keychain \(accessGroup)")
    } else if status == errSecSuccess {
        // Update the item as it is already in the keychain

        // https://developer.apple.com/documentation/security/updating-and-deleting-keychain-items
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        let updateQuery: [String: Any] = [
            kSecValueData as String: token.data(using: .utf8)!
        ]

        let status = SecItemUpdate(searchQuery as CFDictionary, updateQuery as CFDictionary)

        // TODO: Simplify function by checking first attempting update, if status == errSecItemNotFound -> insert
        guard status == errSecSuccess else {
            let res = SecCopyErrorMessageString(status, nil)
            print("Keychain Error while updating (\(status)) -> \(String(describing: res))")
            return false
        }

        print("Updated token in keychain \(accessGroup)")
    } else {
        let res = SecCopyErrorMessageString(status, nil)
        print("Keychain Error while fetching (\(status)) -> \(String(describing: res))")
        return false
    }

    return true
}
