import Foundation

func readConfig() -> (developmentTeam: String, productBundleIdentifier: String)? {
    let pathString = "/usr/local/bin/RotateKeysDaemon.config"
    let url = URL(fileURLWithPath: pathString)

    let content: String
    do {
        content = try String(contentsOf: url, encoding: .utf8)
    } catch {
        print("Can't read config file -> \(error)")
        return nil
    }

    var developmentTeam: String? = nil
    var productBundleIdentifier: String? = nil

    for line in content.split(separator: "\n") {
        if line.trimmingCharacters(in: .whitespaces).isEmpty || line.starts(with: "\\/\\/") { continue }

        let split = line.split(separator: "=", maxSplits: 1)
        if split.count < 2 { continue }

        let key = String(split[0].trimmingCharacters(in: .whitespaces))
        let value = String(split[1].trimmingCharacters(in: .whitespaces))

        if key ==  "DEVELOPMENT_TEAM" {
            developmentTeam = value
        } else if key == "PRODUCT_BUNDLE_IDENTIFIER" {
            productBundleIdentifier = value
        }
    }

    guard let developmentTeam = developmentTeam else {
        print("Can't read config file -> DEVELOPMENT_TEAM is empty")
        return nil
    }

    guard let productBundleIdentifier = productBundleIdentifier else {
        print("Can't read config file -> PRODUCT_BUNDLE_IDENTIFIER is empty")
        return nil
    }

    return (developmentTeam, productBundleIdentifier)
}

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

