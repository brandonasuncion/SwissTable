import XCTest
@testable import SwissTable

final class SwissTableTests: XCTestCase {
    
    func testEntryMemoryLayout() {
        typealias Entry = SwissTable<Int, Int>.Storage.Entry
        
        let expectedSize = MemoryLayout<Int>.size * 3
        let expectedStride = MemoryLayout<Int>.size * 3
        
        XCTAssertEqual(MemoryLayout<Entry>.size, expectedSize)
        XCTAssertEqual(MemoryLayout<Entry>.stride, expectedStride)
    }
    
    func testAllocationSize() {
        for size in -128...32 {
            let table = SwissTable<Int, Int>.init(minimumCapacity: size)
            XCTAssertEqual(table.capacity, 32)
        }
        for size in 33...64 {
            let table = SwissTable<Int, Int>.init(minimumCapacity: size)
            XCTAssertEqual(table.capacity, 64)
        }
        for size in 65...128 {
            let table = SwissTable<Int, Int>.init(minimumCapacity: size)
            XCTAssertEqual(table.capacity, 128)
        }
        for size in 129...256 {
            let table = SwissTable<Int, Int>.init(minimumCapacity: size)
            XCTAssertEqual(table.capacity, 256)
        }
    }
    
    func testReallocation() {
        var table = SwissTable<Int, Int>.init(minimumCapacity: 32)
        
        for i in 0..<16 {
            table[i] = i
        }
        
        for i in 0..<16 {
            XCTAssertEqual(table[i], i)
        }
        
        table.reallocate(capacity: table.capacity)
        
        for i in 0..<16 {
            XCTAssertEqual(table[i], i)
        }
        
        table.reallocate(capacity: table.capacity * 2)
        
        for i in 0..<16 {
            XCTAssertEqual(table[i], i)
        }
    }
    
    func testGrowth() {
        var capacity = 0
        var table = SwissTable<Int, Int>.init(minimumCapacity: 0)
        for size in 1...(1 << 16) {
            table[size] = .random(in: .min ... .max)
            XCTAssertGreaterThanOrEqual(table.capacity, table.count)
            XCTAssertGreaterThanOrEqual(table.capacity, capacity)
            capacity = table.capacity
        }
    }
    
    
    func testInsertDelete() {
        var table: SwissTable<Int, Int> = [:]
        
        table[1] = 2
        
        XCTAssertEqual(table[1], 2)
        XCTAssertEqual(table.count, 1)
        
        table[1] = nil
        
        XCTAssertEqual(table[1], nil)
        XCTAssertEqual(table.count, 0)
    }
    
    func testInsertMany() {
        var table: SwissTable<Int, Int> = [:]
        
        for i in 0..<1000 {
            XCTAssertNil(table[i])
            table[i] = i
            XCTAssertEqual(table[i], i)
        }
        
        for i in 0..<1000 {
            XCTAssertEqual(table[i], i)
        }
    }
    
    func testInsertManyRandom() {
        var table: SwissTable<Int, Int> = [:]
        
        for i in 0..<1000 {
            let k = Int.random(in: .min ... .max)
            table[k] = i
            XCTAssertEqual(table[k], i)
        }
    }
    
    func testCollisions() {
        var table: SwissTable<Int, Int> = [:]
        var dict: [Int: Int] = [:]
        
        let keyRange = 0..<64
        
        for _ in 0..<1000 {
            let k = Int.random(in: keyRange)
            let v = Int.random(in: .min ... .max)
            
            XCTAssertEqual(table[k], dict[k])
            
            table[k, default: 0] ^= v
            dict[k, default: 0] ^= v
            
            XCTAssertEqual(table[k], dict[k])
        }
        
        for k in keyRange {
            XCTAssertEqual(table[k], dict[k])
        }
        
        XCTAssertEqual(table.count, dict.count)
    }
    
    

    static var allTests = [
        ("testEntryMemoryLayout", testEntryMemoryLayout),
        ("testAllocationSize", testAllocationSize),
        ("testReallocation", testReallocation),
        ("testGrowth", testGrowth),
        ("testInsertDelete", testInsertDelete),
        ("testInsertMany", testInsertMany),
        ("testInsertManyRandom", testInsertManyRandom),
        ("testCollisions", testCollisions),
    ]
}
