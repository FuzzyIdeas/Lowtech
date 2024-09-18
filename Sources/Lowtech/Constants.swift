import Foundation

public let ALPHANUMERICS = (
    CharacterSet.decimalDigits.characters().filter(\.isASCII) + CharacterSet.lowercaseLetters.characters()
        .filter(\.isASCII)
).map { String($0) }
public let ALPHANUMERICS_SET = Set(ALPHANUMERICS)
public let ALPHANUMERIC_KEYS = ALPHANUMERICS.compactMap(\.sauceKey)
public let ALPHANUMERIC_KEYS_SET = Set(ALPHANUMERIC_KEYS)
