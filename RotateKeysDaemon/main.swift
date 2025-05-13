import Foundation

print("Welcome to CellGuard's token rotator")

// Generate random UUIDv4 (random) to be used as a token
let token = UUID().uuidString
print("Token: \(token)")

guard writeAppToken(token) else {
    exit(1)
}

guard writeWirelessToken(token) else {
    exit(2)
}

print("Success")
exit(0)
