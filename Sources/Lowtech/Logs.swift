import Foundation

public func debug(_ msg: @autoclosure () -> String) {
    #if DEBUG
        print(msg())
    #endif
}

public func err(_ msg: @autoclosure () -> String) {
    printerr(msg())
}

public func printerr(_ msg: String, end: String = "\n") {
    fputs("\(msg)\(end)", stderr)
}
