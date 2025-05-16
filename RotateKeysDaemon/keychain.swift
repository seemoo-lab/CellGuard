import Foundation
import Security

func writeAppToken(_ token: String) -> Bool {
    // https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
    // https://developer.apple.com/documentation/BundleResources/Entitlements/keychain-access-groups
    // We just use the app id (access group) defined in the entitlements.plist

    // Define search and update query for the item
    // https://developer.apple.com/documentation/security/updating-and-deleting-keychain-items
    // https://developer.apple.com/documentation/security/item-attribute-keys-and-values
    let searchQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "capture-packets-token",
    ]
    let updateQuery: [String: Any] = [
        kSecValueData as String: token.data(using: .utf8)!
    ]

    // Attempt to update the token in the keychain
    // https://developer.apple.com/documentation/security/security-framework-result-codes
    // https://developer.apple.com/documentation/security/errsecmissingentitlement
    let status = SecItemUpdate(searchQuery as CFDictionary, updateQuery as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound else {
        let res = SecCopyErrorMessageString(status, nil)
        print("Keychain Error while updating (\(status)) -> \(String(describing: res))")
        return false
    }

    // This might fail if the token does not already exist in the keychain
    if status == errSecItemNotFound {
        // Add the new item as it is not yet present in the keychain
        // https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain

        // Merge the search & update queries to form an add query
        let addQuery: [String: Any] = searchQuery.merging(updateQuery) { current, _ in current }

        // Add the item
        let status = SecItemAdd(addQuery as CFDictionary, nil)

        // And check the return code
        guard status == errSecSuccess else {
            let res = SecCopyErrorMessageString(status, nil)
            print("Keychain Error while adding (\(status)) -> \(String(describing: res))")
            return false
        }

        print("Inserted token into keychain")
    } else {
        print("Updated token in keychain")
    }

    return true
}
