import Foundation

final class ThreadSafeDictionary<V: Hashable, T>: Collection {
    init(dict: [V: T] = [V: T]()) {
        mutableDictionary = dict
    }

    let accessQueue = DispatchQueue(
        label: "Dictionary Barrier Queue",
        attributes: .concurrent
    )

    var dictionary: [V: T] {
        accessQueue.sync {
            let dict = Dictionary(uniqueKeysWithValues: mutableDictionary.map { ($0.key, $0.value) })
            return dict
        }
    }

    var startIndex: Dictionary<V, T>.Index {
        mutableDictionary.startIndex
    }

    var endIndex: Dictionary<V, T>.Index {
        mutableDictionary.endIndex
    }

    func index(after i: Dictionary<V, T>.Index) -> Dictionary<V, T>.Index {
        mutableDictionary.index(after: i)
    }

    subscript(key: V) -> T? {
        set(newValue) {
            accessQueue.async(flags: .barrier) { [weak self] in
                self?.mutableDictionary[key] = newValue
            }
        }
        get {
            accessQueue.sync {
                self.mutableDictionary[key]
            }
        }
    }

    // has implicity get
    subscript(index: Dictionary<V, T>.Index) -> Dictionary<V, T>.Element {
        accessQueue.sync {
            self.mutableDictionary[index]
        }
    }

    func removeAll() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.mutableDictionary.removeAll()
        }
    }

    func removeValue(forKey key: V) {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.mutableDictionary.removeValue(forKey: key)
        }
    }

    private var mutableDictionary: [V: T]
}
