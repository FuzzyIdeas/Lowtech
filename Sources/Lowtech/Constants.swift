import Foundation

public let ALPHANUMERICS = (
    CharacterSet.decimalDigits.characters().filter(\.isASCII) + CharacterSet.lowercaseLetters.characters()
        .filter(\.isASCII)
).map { String($0) }
public let ALPHANUMERICS_SET = Set(ALPHANUMERICS)
