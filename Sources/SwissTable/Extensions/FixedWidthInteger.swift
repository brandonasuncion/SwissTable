extension FixedWidthInteger {
    @inlinable
    var isPowerOf2: Bool {
        assert(self >= 0)
        return self & (self &- 1) == 0
    }
    
    @inlinable
    func nextPowerOf2() -> Self {
        assert(self >= 0)
        return 1 &<< (Self.bitWidth &- (self &- 1).leadingZeroBitCount)
    }
    
    @inlinable
    func prevPowerOf2() -> Self {
        assert(self >= 0)
        return nextPowerOf2() &>> 1
    }
}

extension FixedWidthInteger {
    @inlinable
    func reduce(_ N: Self) -> Self {
        self.multipliedFullWidth(by: N).high
    }
}

extension FixedWidthInteger where Self: SignedInteger {
    @_transparent
    @inlinable
    func alignedUp(to alignment: Self) -> Self {
        assert(alignment > 0 && alignment.isPowerOf2)
        return (self &+ alignment &- 1) & -alignment
    }
    
    @_transparent
    @inlinable
    func alignedUp<T>(to: T.Type) -> Self {
        return self.alignedUp(to: Self(MemoryLayout<T>.alignment))
    }
}

extension Int {
    @inlinable
    func murmur64() -> Int {
        var h = UInt(bitPattern: self)
        h ^= h &>> 47
        h &*= 0xc6a4a7935bd1e995
        h ^= h &>> 47
        return Int(bitPattern: h)
    }
    
    @inlinable
    func fnv1a() -> Int {
        var h: UInt64 = 0xcbf29ce484222325
        for shift in stride(from: 0, to: 64, by: 8) {
            h ^= UInt64(truncatingIfNeeded: (self &>> shift) & 0xff)
            h &*= 0x100000001b3
        }
        return Int(Int64(bitPattern: h))
    }
}
