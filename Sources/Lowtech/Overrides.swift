import Path
import Sauce

public typealias CustomFilePath = Path
public func p(_ string: String) -> CustomFilePath? {
    CustomFilePath(string)
}

public typealias SauceKey = Key
