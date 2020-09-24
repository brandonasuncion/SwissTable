public struct SwissTable<Key: Hashable, Value> {
    
    @usableFromInline
    var storage: Storage
    
    // A strong reference is kept to the hashtable's storage, but
    // pointers are kept to point directly to the table's contents for speed.
    // Swift's standard library does something similar.
    
    @usableFromInline
    let control: UnsafeMutableBufferPointer<Int8>
    
    @usableFromInline
    let entries: UnsafeMutableBufferPointer<Storage.Entry>
    
    @usableFromInline
    var _count: Int = 0
    
    @inlinable
    public var count: Int {
        _count
    }
    
    @inlinable
    public var capacity: Int {
        control.count
    }
    
    @inlinable
    @inline(__always)
    init(exactCapacity capacity: Int) {
        assert(capacity.isPowerOf2 && capacity >= 32)
        let storage = Self.allocateStorage(size: capacity)
        
        self.storage = storage
        self.control = storage.controlBytes
        self.entries = storage.entries
    }
    
    @inlinable
    @inline(__always)
    public init(minimumCapacity: Int) {
        let capacity = Swift.max(minimumCapacity, 32).nextPowerOf2()
        let storage = Self.allocateStorage(size: capacity)
        
        self.storage = storage
        self.control = storage.controlBytes
        self.entries = storage.entries
    }
}

extension SwissTable {
    
    @inlinable
    @_transparent
    var groupSize: Int {
        32
    }
    
    @inlinable
    @_transparent
    var groupCount: Int {
        // division by groupSize seems to produce unoptimal assembly
        // capacity / groupSize
        capacity &>> 5
    }
    
    @inlinable
    @_transparent
    func controlBytes(group: Int) -> UnsafeMutablePointer<Int8> {
        let firstIndex = group &* groupSize
        return control.baseAddress!.advanced(by: firstIndex)
    }
    
    @inlinable
    @_transparent
    func controlByte(for hash: Int) -> Int8 {
        Int8(UInt(bitPattern: hash) &>> 57)
    }
    
    @inlinable
    @_transparent
    func group(for hash: Int) -> Int {
        assert(capacity > 0 && capacity.isPowerOf2)
        assert(groupCount > 0 && groupCount.isPowerOf2)
        
        return hash & (groupCount &- 1)
    }
    
}


import _Builtin_intrinsics.intel

// MARK: SIMD-accelerated scan methods
extension SwissTable {
    
    @_effects(readonly)
    @inlinable
    @inline(__always)
    func find(key: Key, hash: Int, group: Int) -> Int? {
        let controlByte = self.controlByte(for: hash)
        let groupPointer = controlBytes(group: group)
        let cmp = _mm256_cmpeq_epi8(
            _mm256_set1_epi8(controlByte),
            _mm256_loadu_epi8(groupPointer)
        )
        var mask = _mm256_movemask_epi8(cmp)
        while mask != 0 {
            let idx = (group &* groupSize) &+ mask.trailingZeroBitCount
            
            if _fastPath(key == entries[idx].key) {
                return idx
            }
            
            mask &= mask &- 1
        }
        
        return nil
    }
    
    @_effects(readonly)
    @inlinable
    @inline(__always)
    func findEmpty(group: Int) -> Int? {
        let groupPointer = self.controlBytes(group: group)
        let emptyMask = _mm256_movemask_epi8(_mm256_loadu_epi8(groupPointer))
        guard _fastPath(emptyMask != 0) else {
            return nil
        }
        return (group &* groupSize) &+ emptyMask.trailingZeroBitCount
    }
    
    @_effects(readonly)
    @inlinable
    @_transparent
    func nonemptyMask(group: Int) -> UInt32 {
        let groupPointer = controlBytes(group: group)
        let emptyMask = _mm256_movemask_epi8(_mm256_loadu_epi8(groupPointer))
        return UInt32(bitPattern: ~emptyMask)
    }
    
}


// MARK: Internal get/set/clear/reallocate methods
extension SwissTable {
    
    @_effects(readonly)
    @inlinable
    func get(key: Key, hash: Int) -> Value? {
        let group = self.group(for: hash)
        
        guard let index = find(key: key, hash: hash, group: group) else {
            return nil
        }
        
        return entries[index].value
    }
    
    @inlinable
    mutating func set(hash: Int, key: Key, value: Value) {
        let group = self.group(for: hash)
    
        if let index = find(key: key, hash: hash, group: group) {
    
            // Insert into a preexisting slot
            entries[index] = .init(hash: hash, key: key, value: value)
    
        } else if let index = findEmpty(group: group) {
    
            // Insert into an empty slot
            entries[index] = .init(hash: hash, key: key, value: value)
            control[index] = controlByte(for: hash)
            _count &+= 1
    
        } else if _slowPath(true) {
            // Reallocate if a slot is not available
            self.reallocate(capacity: capacity &<< 1)
            self.set(hash: hash, key: key, value: value)
        }
    }
    
    @inlinable
    mutating func clear(hash: Int, key: Key) {
        let group = self.group(for: hash)
        guard let index = find(key: key, hash: hash, group: group) else {
            return
        }
        control[index] = -1
        _count &-= 1
    }
    
    
    /// Insert an entry without checking if a matching entry exists
    @inlinable
    mutating func uniqueSet(hash: Int, key: Key, value: Value) {
        let group = self.group(for: hash)
        
        if let index = findEmpty(group: group) {
            
            // Insert into an empty slot
            entries[index] = .init(hash: hash, key: key, value: value)
            control[index] = controlByte(for: hash)
            
        } else {
            // Reallocate if a slot is not available
            self.reallocate(capacity: capacity &<< 1)
            self.uniqueSet(hash: hash, key: key, value: value)
        }
    }
    
    @_effects(releasenone)
    @inlinable
    mutating func reallocate(capacity: Int) {
        
        // let loadFactor = Double(_count) / Double(self.capacity)
        // print("\(_count) / \(self.capacity) = \(loadFactor)")
        
        // dumpControls()
        // dumpControlsFull()
        
        var new = Self(exactCapacity: capacity)
        
        for group in 0..<groupCount {
            var mask = nonemptyMask(group: group)
            while mask != 0 {
                let index = (group &* groupSize) &+ mask.trailingZeroBitCount
                let entry = entries[index]
                new.uniqueSet(hash: entry.hash, key: entry.key, value: entry.value)
        
                mask &= mask &- 1
            }
        }
        
        new._count = self.count
        self = new
    }
    
}

extension SwissTable {
    
    public subscript(key: Key) -> Value? {
        @_transparent
        get {
            let hash = _hashValue(for: key)
            return get(key: key, hash: hash)
        }
        
        @_transparent
        set {
            if !isKnownUniquelyReferenced(&storage) {
                reallocate(capacity: capacity)
            }
            
            let hash = _hashValue(for: key)
            if let value = newValue {
                set(hash: hash, key: key, value: value)
            } else {
                clear(hash: hash, key: key)
            }
        }
    }
    
    public subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        @_transparent
        get {
            let hash = _hashValue(for: key)
            return get(key: key, hash: hash) ?? defaultValue()
        }
        
        @_transparent
        set {
            if !isKnownUniquelyReferenced(&storage) {
                reallocate(capacity: capacity)
            }
            
            let hash = _hashValue(for: key)
            set(hash: hash, key: key, value: newValue)
        }
    }
}


extension SwissTable {
    @inlinable
    func dumpControls() {
        print("\(control.count) entries")
        for byte in control {
            print("\t- \(byte == -1 ? "empty" : String(byte))")
        }
    }
    
    @inlinable
    func dumpVacancy() {
        print("\(control.count) entries")
        var text: String = ""
        for byte in control {
            text += byte == -1 ? "_" : "X"
        }
        print(text)
    }
}
