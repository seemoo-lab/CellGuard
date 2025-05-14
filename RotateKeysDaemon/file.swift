import Foundation

func writeWirelessToken(_ token: String) -> Bool {
    let pathString = "/var/wireless/Documents/CapturePacketsTweak/token.txt"
    let url = URL(fileURLWithPath: pathString)
    do {
        try token.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        print("Write Error -> \(error)")
        return false
    }

    print("Wrote token to \(pathString)")

    return true
}

