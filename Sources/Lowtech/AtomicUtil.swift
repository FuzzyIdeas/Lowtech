import Atomics

// MARK: - Atomic

@propertyWrapper
public struct Atomic<Value: AtomicValue> where Value.AtomicRepresentation.Value == Value {
    public init(wrappedValue: Value) {
        value = ManagedAtomic<Value>(wrappedValue)
    }

    public var wrappedValue: Value {
        get { value.load(ordering: .relaxed) }
        set { value.store(newValue, ordering: .sequentiallyConsistent) }
    }

    var value: ManagedAtomic<Value>
}
