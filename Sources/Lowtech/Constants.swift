import Foundation

public let ALPHANUMERICS = (
    CharacterSet.decimalDigits.characters().filter(\.isASCII) + CharacterSet.lowercaseLetters.characters()
        .filter(\.isASCII)
).map { String($0) }
public let ALPHANUMERICS_SET = Set(ALPHANUMERICS)
public var ALPHANUMERIC_KEYS = ALPHANUMERICS.compactMap(\.sauceKey)
public var ALPHANUMERIC_KEYS_SET = Set(ALPHANUMERIC_KEYS)
