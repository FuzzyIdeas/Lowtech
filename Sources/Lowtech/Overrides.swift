import Path

public typealias FilePath = Path
public func p(_ string: String) -> FilePath? {
    FilePath(string)
}
