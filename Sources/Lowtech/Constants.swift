import Foundation
import Regex

public let BUNDLE_IDENTIFIER_PATTERN = #"([^:]+):(\d+)"#.r!
public let ALPHANUMERICS = (
    CharacterSet.decimalDigits.characters().filter(\.isASCII) + CharacterSet.lowercaseLetters.characters()
        .filter(\.isASCII)
).map { String($0) }
public let ALPHANUMERICS_SET = Set(ALPHANUMERICS)
