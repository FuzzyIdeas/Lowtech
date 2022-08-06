import Path

public typealias CustomFilePath = Path
public func p(_ string: String) -> CustomFilePath? {
    CustomFilePath(string)
}
