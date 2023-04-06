import Atomics

// MARK: - Atomic

@propertyWrapper
public struct Atomic<Value: AtomicValue> where Value.AtomicRepresentation.Value == Value {
    // MARK: Lifecycle

    public init(wrappedValue: Value) {
        value = ManagedAtomic<Value>(wrappedValue)
    }

    // MARK: Public

    public var wrappedValue: Value {
        get { value.load(ordering: .relaxed) }
        set { value.store(newValue, ordering: .sequentiallyConsistent) }
    }

    // MARK: Internal

    var value: ManagedAtomic<Value>
}
