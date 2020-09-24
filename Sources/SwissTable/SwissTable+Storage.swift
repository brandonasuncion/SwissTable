import struct SwiftShims.HeapObject

extension SwissTable {
    
    /// A reference-counted buffer for storing control bytes and table entries in a singlular heap allocation
    @usableFromInline
    @_fixed_layout
    @_objc_non_lazy_realization
    final class Storage: Swift.ManagedBuffer<Storage.Header, Int8> {
        
        @inlinable
        @inline(__always)
        var size: Int {
            header.size
        }
        
        @inlinable
        deinit {
            controlBytes.baseAddress!.deinitialize(count: size)
            entries.baseAddress!.deinitialize(count: size)
        }
    }
    
    @inlinable
    static func allocateUninitializedStorage(size: Int) -> Storage {
        var bufferSize = size.alignedUp(to: Storage.Entry.self)
        bufferSize += MemoryLayout<Storage.Entry>.stride &* size
        
        return Storage.create(minimumCapacity: bufferSize) { buffer in
            Storage.Header(size: size)
        } as! Storage
    }
    
    @inlinable
    static func allocateStorage(size: Int) -> Storage {
        let buffer = allocateUninitializedStorage(size: size)
        buffer.rawBody.initializeMemory(as: Int8.self, repeating: -1)
        return buffer
    }
    
    @inlinable
    static func copyStorage(source: Storage, newSize size: Int) -> Storage {
        assert(size >= source.size)
        let buffer = allocateUninitializedStorage(size: size)
        
        let sourcePointer = source.rawBody.baseAddress!.assumingMemoryBound(to: Int8.self)
        let destPointer = buffer.rawBody.baseAddress!
        
        destPointer.moveInitializeMemory(
            as: Int8.self,
            from: sourcePointer,
            count: source.bodyByteSize
        )
        
        let growth = size - source.size
        let uninitialized = destPointer.assumingMemoryBound(to: Int8.self) + source.bodyByteSize
        uninitialized.initialize(repeating: -1, count: growth)
        
        return buffer
    }
    
}


extension SwissTable.Storage {
    
    @frozen
    @usableFromInline
    struct Header {
        
        @usableFromInline
        let size: Int
        
        @inlinable
        init(size: Int) {
            self.size = size
        }
    }
    
    @frozen
    @usableFromInline
    struct Entry {
        
        @usableFromInline let hash: Int
        @usableFromInline let key: Key
        @usableFromInline let value: Value
        
        @inlinable
        init(hash: Int, key: Key, value: Value) {
            self.hash = hash
            self.key = key
            self.value = value
        }
    }
}

extension SwissTable.Storage {
    
    // Using a manually allocated buffer would be cleaner,
    // but a ManagedBuffer is used for copy-on-write.
    // https://www.cocoawithlove.com/blog/2016/09/22/deque.html
    
    @inlinable
    @inline(__always)
    var bodyByteSize: Int {
        size.alignedUp(to: MemoryLayout<Entry>.alignment)
            + MemoryLayout<Entry>.stride &* size
    }
    
    @inlinable
    @inline(__always)
    var rawBody: UnsafeMutableRawBufferPointer {
        self.withUnsafeMutablePointerToElements { (elements: UnsafeMutablePointer<Int8>) -> UnsafeMutableRawBufferPointer in
            UnsafeMutableRawBufferPointer(start: elements, count: bodyByteSize)
        }
    }
    
    @inlinable
    @inline(__always)
    var controlBytes: UnsafeMutableBufferPointer<Int8> {
        var value = unsafeBitCast(self, to: Int.self)
        value &+= MemoryLayout<HeapObject>.size
        
        value = value.alignedUp(to: Header.self)
        value &+= MemoryLayout<Header>.stride
        
        let base = UnsafeMutablePointer<Int8>(bitPattern: value)
        return .init(start: base, count: self.size)
    }
    
    @inlinable
    @inline(__always)
    var entries: UnsafeMutableBufferPointer<Entry> {
        var value = unsafeBitCast(self, to: Int.self)
        value &+= MemoryLayout<HeapObject>.size
        
        value = value.alignedUp(to: Header.self)
        value &+= MemoryLayout<Header>.stride
        
        // size of control bytes
        value &+= self.size
        
        // align up to Entry alignment
        value = value.alignedUp(to: Entry.self)
        
        let base = UnsafeMutablePointer<Entry>(bitPattern: value)
        return .init(start: base, count: self.size)
    }
    
}
