import AppReceiptValidator

@inline(__always)
public func validReceipt() -> Bool {
    switch AppReceiptValidator().validateReceipt() {
    case .success(_, receiptData: _, deviceIdentifier: _):
        return true
    default:
        return false
    }
}
