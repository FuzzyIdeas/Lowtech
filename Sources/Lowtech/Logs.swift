import Foundation

public func debug(_ msg: @autoclosure () -> Any, function: String = #function) {
    #if DEBUG
        print("\(function): \(msg())")
    #endif
}

public func err(_ msg: @autoclosure () -> Any, function: String = #function) {
    printerr("\(function): \(msg())")
}

public func printerr(_ msg: String, end: String = "\n") {
    fputs("\(msg)\(end)", stderr)
}
