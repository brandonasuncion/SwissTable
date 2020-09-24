extension SwissTable: Sequence {
    public typealias Element = (key: Key, value: Value)
    
    public struct Iterator: IteratorProtocol {
        
        @inlinable
        internal init(table: SwissTable<Key, Value>) {
            self.table = table
            self.iterator = table.control.enumerated().makeIterator()
        }
        
        @usableFromInline
        internal let table: SwissTable
        
        @usableFromInline
        internal var iterator: EnumeratedSequence<UnsafeMutableBufferPointer<Int8>>.Iterator
        
        @inlinable
        public mutating func next() -> (key: Key, value: Value)? {
            
            // TODO: Manually vectorize this loop
            while let (index, control) = iterator.next() {
                if control != -1 {
                    let entry = table.entries[index]
                    return (key: entry.key, value: entry.value)
                }
            }
            return nil
        }
        
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(table: self)
    }
}



extension SwissTable: Equatable where Value: Equatable {
    public static func == (lhs: SwissTable<Key, Value>, rhs: SwissTable<Key, Value>) -> Bool {
        // TODO: Implement
        false
    }
}

extension SwissTable: Hashable where Value: Hashable {
    
    // same as Swift's stdlib
    public func hash(into hasher: inout Hasher) {
        var result = 0
        for (k, v) in self {
            var elementHasher = hasher
            elementHasher.combine(k)
            elementHasher.combine(v)
            result ^= elementHasher.finalize()
        }
        
        hasher.combine(result)
    }
}



extension SwissTable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(minimumCapacity: elements.count &* 2)
        for (key, value) in elements {
            self[key] = value
        }
    }
}

extension SwissTable {
    public init<S>(uniqueKeysWithValues keysAndValues: S) where S : Sequence, S.Element == (Key, Value) {
        self.init(minimumCapacity: keysAndValues.underestimatedCount &* 2)
        for (key, value) in keysAndValues {
            self[key] = value
        }
    }
}
