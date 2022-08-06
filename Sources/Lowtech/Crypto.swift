import CryptoKit
import Foundation
import Security

public extension String {
    var sha1: String {
        var s = Insecure.SHA1()
        s.update(data: data(using: .utf8)!)
        return s.finalize().hexEncodedString()
    }
}

public extension Bundle {
    var isTestFlight: Bool {
        var status = noErr

        var code: SecStaticCode?
        status = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &code)
        guard status == noErr, let code = code else {
            return false
        }

        var requirement: SecRequirement?
        status = SecRequirementCreateWithString(
            "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]" as CFString,
            [], &requirement
        )
        guard status == noErr, let requirement = requirement else {
            return false
        }

        return SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}
