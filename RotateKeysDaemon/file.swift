import Foundation

func writeWirelessToken(_ token: String) -> Bool {
    let pathString = "/var/wireless/Documents/CapturePacketsTweak/token.txt"
    let url = URL(fileURLWithPath: pathString)
    do {
        // Create the directory (with permissions for _wireless user) if it does not exist
        let fm = FileManager()
        let parent = url.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [
            .ownerAccountName: "_wireless",
            .groupOwnerAccountName: "_wireless",
            .posixPermissions: 0o751 // rwxr-x--x
        ])
        // Write the token
        let tokenData = Data(token.utf8)
        fm.createFile(atPath: pathString, contents: tokenData, attributes: [
            .posixPermissions: 0o660 // rw-rw----
        ])
        try token.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        print("Write Error -> \(error)")
        return false
    }

    print("Wrote token to \(pathString)")

    return true
}

