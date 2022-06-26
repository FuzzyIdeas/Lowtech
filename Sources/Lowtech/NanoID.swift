//
//  NanoID.swift
//
//  Created by Anton Lovchikov on 05/07/2018.
//  Copyright © 2018 Anton Lovchikov. All rights reserved.
//

import Foundation

// MARK: - NanoID

/// USAGE
///
/// Nano ID with default alphabet (0-9a-zA-Z_~) and length (21 chars)
/// let id = NanoID.new()
///
/// Nano ID with default alphabet and given length
/// let id = NanoID.new(12)
///
/// Nano ID with given alphabet and length
/// let id = NanoID.new(alphabet: .uppercasedLatinLetters, size: 15)
///
/// Nano ID with preset custom parameters
/// let nanoID = NanoID(alphabet: .lowercasedLatinLetters,.numbers, size:10)
/// let idFirst = nanoID.new()
/// let idSecond = nanoID.new()

public class NanoID {
    // MARK: Lifecycle

    /// Inits an instance with Shared Parameters
    public init(alphabet: NanoIDAlphabet..., size: Int) {
        self.size = size
        self.alphabet = NanoIDHelper.parse(alphabet)
    }

    // MARK: Public

    /// Generates a Nano ID using Default Parameters
    public static func new() -> String {
        NanoIDHelper.generate(from: defaultAphabet, of: defaultSize)
    }

    /// Generates a Nano ID using given occasional parameters
    public static func new(alphabet: NanoIDAlphabet..., size: Int) -> String {
        let charactersString = NanoIDHelper.parse(alphabet)
        return NanoIDHelper.generate(from: charactersString, of: size)
    }

    /// Generates a Nano ID using Default Alphabet and given size
    public static func new(_ size: Int) -> String {
        NanoIDHelper.generate(from: NanoID.defaultAphabet, of: size)
    }

    /// Generates a Nano ID using Shared Parameters
    public func new() -> String {
        NanoIDHelper.generate(from: alphabet, of: size)
    }

    // MARK: Private

    // Default Parameters
    private static let defaultSize = 21
    private static let defaultAphabet = NanoIDAlphabet.urlSafe.toString()

    // Shared Parameters
    private var size: Int
    private var alphabet: String
}

// MARK: - NanoIDHelper

private enum NanoIDHelper {
    /// Parses input alphabets into a string
    static func parse(_ alphabets: [NanoIDAlphabet]) -> String {
        var stringCharacters = ""

        for alphabet in alphabets {
            stringCharacters.append(alphabet.toString())
        }

        return stringCharacters
    }

    /// Generates a Nano ID using given parameters
    static func generate(from alphabet: String, of length: Int) -> String {
        var nanoID = ""

        for _ in 0 ..< length {
            let randomCharacter = NanoIDHelper.randomCharacter(from: alphabet)
            nanoID.append(randomCharacter)
        }

        return nanoID
    }

    /// Returns a random character from a given string
    static func randomCharacter(from string: String) -> Character {
        let randomNum = arc4random_uniform(string.count.u32).i
        let randomIndex = string.index(string.startIndex, offsetBy: randomNum)
        return string[randomIndex]
    }
}

// MARK: - NanoIDAlphabet

public enum NanoIDAlphabet {
    case urlSafe
    case uppercasedLatinLetters
    case lowercasedLatinLetters
    case numbers

    // MARK: Public

    public func toString() -> String {
        switch self {
        case .uppercasedLatinLetters, .lowercasedLatinLetters, .numbers:
            return chars()
        case .urlSafe:
            return (
                "\(NanoIDAlphabet.uppercasedLatinLetters.chars())\(NanoIDAlphabet.lowercasedLatinLetters.chars())\(NanoIDAlphabet.numbers.chars())~_"
            )
        }
    }

    // MARK: Private

    private func chars() -> String {
        switch self {
        case .uppercasedLatinLetters:
            return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        case .lowercasedLatinLetters:
            return "abcdefghijklmnopqrstuvwxyz"
        case .numbers:
            return "1234567890"
        default:
            return ""
        }
    }
}
