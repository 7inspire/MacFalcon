import XCTest
import MonitorCore
import Darwin

final class MonitorCoreTests: XCTestCase {
    func testProcessListContainsSelfAndIdentityMatches() {
        var pointer: UnsafeMutablePointer<MMProcess>?
        let count = mm_processes(&pointer)
        XCTAssertGreaterThan(count, 0)
        guard let pointer else { return XCTFail("No process list") }
        defer { mm_free(pointer) }
        guard let own = (0..<count).map({ pointer[$0] }).first(where: { $0.pid == getpid() }) else { return XCTFail("Current process missing") }
        XCTAssertGreaterThan(own.resident, 0)
        XCTAssertEqual(mm_process_matches(own.pid, own.start_time), 1)
        XCTAssertEqual(mm_process_matches(own.pid, own.start_time + 1), 0)
        var arguments = [CChar](repeating: 0, count: 4096)
        XCTAssertEqual(mm_process_arguments(own.pid, own.start_time + 1, &arguments, arguments.count), 0)
    }
    func testCPUTimeMatchesBusyWork() {
        func cpuTime() -> UInt64 {
            var pointer: UnsafeMutablePointer<MMProcess>?
            let count = mm_processes(&pointer)
            guard let pointer else { return 0 }
            defer { mm_free(pointer) }
            return (0..<count).map { pointer[$0] }.first { $0.pid == getpid() }?.cpu_ns ?? 0
        }
        let before = cpuTime()
        let until = Date().addingTimeInterval(0.15)
        while Date() < until { _ = sqrt(12345.0) }
        let after = cpuTime()
        XCTAssertGreaterThan(after, before)
        XCTAssertGreaterThan(Double(after - before) / 1e9, 0.05, "CPU time must be converted from Mach ticks to nanoseconds")
    }
    func testSystemCounters() {
        var cpu = MMCPU(), memory = MMMemory(), network = MMNetwork()
        XCTAssertEqual(mm_cpu(&cpu), 1)
        var cores: UnsafeMutablePointer<MMCPU>?
        let coreCount = mm_cpu_cores(&cores)
        XCTAssertGreaterThan(coreCount, 0)
        if let cores { mm_free(cores) }
        XCTAssertGreaterThan(cpu.user + cpu.system + cpu.idle + cpu.nice, 0)
        XCTAssertEqual(mm_memory(&memory), 1)
        XCTAssertGreaterThan(memory.total, 0)
        XCTAssertLessThanOrEqual(memory.free, memory.total)
        XCTAssertEqual(mm_network(&network), 1)
    }
}
