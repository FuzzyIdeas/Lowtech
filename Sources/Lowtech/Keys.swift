//
//  Keys.swift
//
//
//  Created by Alin Panaitiu on 21.01.2022.
//

import Atomics
import Foundation

var _rcmd = ManagedAtomic<Bool>(false)
var rcmd: Bool {
    get { _rcmd.load(ordering: .relaxed) }
    set { _rcmd.store(newValue, ordering: .sequentiallyConsistent) }
}

var _ralt = ManagedAtomic<Bool>(false)
var ralt: Bool {
    get { _ralt.load(ordering: .relaxed) }
    set { _ralt.store(newValue, ordering: .sequentiallyConsistent) }
}

var _rshift = ManagedAtomic<Bool>(false)
var rshift: Bool {
    get { _rshift.load(ordering: .relaxed) }
    set { _rshift.store(newValue, ordering: .sequentiallyConsistent) }
}

var _rctrl = ManagedAtomic<Bool>(false)
var rctrl: Bool {
    get { _rctrl.load(ordering: .relaxed) }
    set { _rctrl.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lcmd = ManagedAtomic<Bool>(false)
var lcmd: Bool {
    get { _lcmd.load(ordering: .relaxed) }
    set { _lcmd.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lalt = ManagedAtomic<Bool>(false)
var lalt: Bool {
    get { _lalt.load(ordering: .relaxed) }
    set { _lalt.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lctrl = ManagedAtomic<Bool>(false)
var lctrl: Bool {
    get { _lctrl.load(ordering: .relaxed) }
    set { _lctrl.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lshift = ManagedAtomic<Bool>(false)
var lshift: Bool {
    get { _lshift.load(ordering: .relaxed) }
    set { _lshift.store(newValue, ordering: .sequentiallyConsistent) }
}
