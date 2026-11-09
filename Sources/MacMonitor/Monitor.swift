import Foundation
import AppKit
import MonitorCore
import IOKit.ps

struct ProcessInfoRow: Identifiable {
    let id: Int32
    let parent: Int32
    let uid: UInt32
    let name: String
    let path: String
    let memory: UInt64
    let virtualMemory: UInt64
    let startTime: UInt64
    let cpuTime: UInt64
    let threads: Int
    let ioAvailable: Bool
    let read: UInt64
    let write: UInt64
    var cpu: Double = 0
    var readRate: Double = 0
    var writeRate: Double = 0
}
struct PriorityRule: Codable, Identifiable, Equatable {
    var id: String { path }
    var path: String
    var nice: Int32
}
struct Sample: Identifiable {
    let id = UUID()
    let time: Date
    let cpu: Double
    let memory: Double
    let download: Double
    let upload: Double
}
struct Snapshot {
    var processes: [ProcessInfoRow] = []
    var cpu = 0.0
    var coreUsage: [Double] = []
    var validDelta = false
    var ruleErrors: [String] = []
    var memory = MMMemory()
    var download = 0.0
    var upload = 0.0
    var diskReadRate: Double?
    var diskWriteRate: Double?
    var diskTotal: UInt64 = 0
    var diskFree: UInt64 = 0
    var battery: String = tr("不可用")
    var hardware = MMHardware()
    var sampledAt = Date()
}

private func stringFromTuple<T>(_ value: T) -> String {
    var value = value
    return withUnsafePointer(to: &value) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { String(cString: $0) }
    }
}
private func delta(_ now: UInt64, _ before: UInt64) -> UInt64 { now >= before ? now - before : 0 }

final class Sampler: @unchecked Sendable {
    private var previousCPU: MMCPU?
    private var previousCores: [MMCPU] = []
    private var previousNetwork: MMNetwork?
    private var previousDisk: MMDiskIO?
    private var previousProcesses: [Int32: ProcessInfoRow] = [:]
    private var previousTime: Date?
    private var hardware = MMHardware()
    private var hardwareTime = Date.distantPast
    private var appliedRules: [String: Int32] = [:]

    func collect(rules: [PriorityRule] = []) -> Snapshot {
        let now = Date()
        let elapsed = previousTime.map { now.timeIntervalSince($0) } ?? 0
        var result = Snapshot()
        result.sampledAt = now
        var cpu = MMCPU()
        if mm_cpu(&cpu) != 0 {
            if let old = previousCPU {
                let user = delta(cpu.user, old.user) + delta(cpu.nice, old.nice)
                let system = delta(cpu.system, old.system)
                let idle = delta(cpu.idle, old.idle)
                let total = user + system + idle
                if total > 0 { result.cpu = Double(user + system) / Double(total) * 100 }
            }
            previousCPU = cpu
        }
        var corePointer: UnsafeMutablePointer<MMCPU>?
        let coreCount = mm_cpu_cores(&corePointer)
        if let corePointer {
            let cores = Array(UnsafeBufferPointer(start: corePointer, count: coreCount))
            mm_free(corePointer)
            if cores.count == previousCores.count {
                result.coreUsage = zip(cores, previousCores).map { current, old in
                    let active = delta(current.user, old.user) + delta(current.system, old.system) + delta(current.nice, old.nice)
                    let total = active + delta(current.idle, old.idle)
                    return total > 0 ? Double(active) / Double(total) * 100 : 0
                }
            }
            previousCores = cores
        }
        result.validDelta = elapsed > 0
        _ = mm_memory(&result.memory)
        var network = MMNetwork()
        if mm_network(&network) != 0 {
            if let old = previousNetwork, elapsed > 0 {
                result.download = Double(delta(network.received, old.received)) / elapsed
                result.upload = Double(delta(network.sent, old.sent)) / elapsed
            }
            previousNetwork = network
        }
        var disk = MMDiskIO()
        mm_disk_io(&disk)
        if disk.available != 0 {
            if let old = previousDisk, old.available != 0, elapsed > 0 {
                result.diskReadRate = Double(delta(disk.read_bytes, old.read_bytes)) / elapsed
                result.diskWriteRate = Double(delta(disk.write_bytes, old.write_bytes)) / elapsed
            }
            previousDisk = disk
        } else { previousDisk = nil }
        var ptr: UnsafeMutablePointer<MMProcess>?
        let count = mm_processes(&ptr)
        if let ptr {
            defer { mm_free(ptr) }
            result.processes.reserveCapacity(count)
            for i in 0..<count {
                let p = ptr[i]
                var row = ProcessInfoRow(id: p.pid, parent: p.ppid, uid: p.uid, name: stringFromTuple(p.name), path: stringFromTuple(p.path), memory: p.resident, virtualMemory: p.virtual_size, startTime: p.start_time, cpuTime: p.cpu_ns, threads: Int(p.threads), ioAvailable: p.io_available != 0, read: p.read_bytes, write: p.write_bytes)
                if let old = previousProcesses[p.pid], old.startTime == row.startTime, elapsed > 0 {
                    row.cpu = Double(delta(row.cpuTime, old.cpuTime)) / 1_000_000_000 / elapsed * 100
                    if row.ioAvailable && old.ioAvailable {
                        row.readRate = Double(delta(row.read, old.read)) / elapsed
                        row.writeRate = Double(delta(row.write, old.write)) / elapsed
                    }
                }
                result.processes.append(row)
            }
        }
        let rulesByPath = Dictionary(rules.map { ($0.path, $0.nice) }, uniquingKeysWith: { _, last in last })
        var currentIdentities = Set<String>()
        for process in result.processes where process.id > 1 && process.id != getpid() {
            let key = "\(process.id)-\(process.startTime)"
            currentIdentities.insert(key)
            guard let priority = rulesByPath[process.path] else { appliedRules.removeValue(forKey: key); continue }
            guard appliedRules[key] != priority else { continue }
            appliedRules[key] = priority // Attempt only once per process and rule to avoid repeated privileged calls.
            if mm_process_matches(process.id, process.startTime) != 0 && setpriority(PRIO_PROCESS, id_t(process.id), priority) != 0 {
                result.ruleErrors.append("\(process.name) (PID \(process.id))：\(String(cString: strerror(errno)))")
            }
        }
        appliedRules = appliedRules.filter { currentIdentities.contains($0.key) }
        previousProcesses = Dictionary(result.processes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        previousTime = now
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            result.diskTotal = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
            result.diskFree = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        }
        if now.timeIntervalSince(hardwareTime) >= 15 { mm_hardware(&hardware); hardwareTime = now }
        result.hardware = hardware
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
           let source = sources.first,
           let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
           let current = info[kIOPSCurrentCapacityKey] as? Int,
           let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 {
            let state = (info[kIOPSIsChargingKey] as? Bool) == true ? tr("充电中") : ((info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue ? tr("接通电源") : tr("电池供电"))
            result.battery = "\(current * 100 / max)% · \(state)"
        }
        return result
    }
}

@MainActor final class Monitor: ObservableObject {
    @Published var snapshot = Snapshot()
    @Published var history: [Sample] = []
    @Published var records: [HistoricalRecord] = []
    @Published var historyError: String?
    @Published var ruleFailures: [String] = []
    @Published var priorityRules: [PriorityRule] = (UserDefaults.standard.data(forKey: "priorityRules").flatMap { try? JSONDecoder().decode([PriorityRule].self, from: $0) } ?? []) {
        didSet { if let data = try? JSONEncoder().encode(priorityRules) { UserDefaults.standard.set(data, forKey: "priorityRules") } }
    }
    private let historyStore = HistoryStore()
    @Published var isPaused = false
    @Published var backgroundHistory = UserDefaults.standard.bool(forKey: "backgroundHistory") { didSet { UserDefaults.standard.set(backgroundHistory, forKey: "backgroundHistory") } }
    private var lastBackgroundSample = Date.distantPast
    @Published var interval: Double = 3 { didSet { restartTimer() } }
    private let sampler = Sampler()
    private let queue = DispatchQueue(label: "com.macmonitor.sampler", qos: .utility)
    private var timer: Timer?
    private var collecting = false
    private var observers: [NSObjectProtocol] = []

    init() {
        interval = UserDefaults.standard.object(forKey: "interval") as? Double ?? 3
        restartTimer()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
    }
    func restartTimer() {
        UserDefaults.standard.set(interval, forKey: "interval")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        refresh()
    }
    func refresh() {
        guard !isPaused, !collecting else { return }
        // Avoid collecting while every app window is hidden or minimized.
        let visible = !NSApp.isHidden && NSApp.windows.contains(where: { $0.isVisible && !$0.isMiniaturized && $0.canBecomeMain && $0.level == .normal })
        if !visible {
            guard backgroundHistory, Date().timeIntervalSince(lastBackgroundSample) >= 60 else { return }
            lastBackgroundSample = Date()
        }
        collecting = true
        let sampler = self.sampler
        let rules = self.priorityRules
        let historyStore = self.historyStore
        queue.async { [weak self] in
            let snapshot = autoreleasepool { sampler.collect(rules: rules) }
            if snapshot.validDelta { historyStore.save(snapshot) }
            let storeError = historyStore.error
            DispatchQueue.main.async {
                guard let self else { return }
                self.snapshot = snapshot
                if !snapshot.ruleErrors.isEmpty { self.ruleFailures = snapshot.ruleErrors }
                self.historyError = storeError
                let memory = snapshot.memory.total > 0 ? Double(snapshot.memory.active + snapshot.memory.wired + snapshot.memory.compressed) / Double(snapshot.memory.total) * 100 : 0
                self.history.append(Sample(time: snapshot.sampledAt, cpu: snapshot.cpu, memory: min(memory, 100), download: snapshot.download, upload: snapshot.upload))
                if self.history.count > 120 { self.history.removeFirst(self.history.count - 120) }
                self.collecting = false
            }
        }
    }
    func setRule(path: String, nice: Int32) {
        guard !path.isEmpty else { return }
        priorityRules.removeAll { $0.path == path }
        priorityRules.append(PriorityRule(path: path, nice: nice))
        refresh()
    }
    func clearHistory() {
        let store = historyStore
        queue.async { [weak self] in
            store.clear()
            let error = store.error
            DispatchQueue.main.async { self?.records = []; self?.historyError = error }
        }
    }
    func loadHistory(hours: Int) {
        let store = historyStore
        queue.async { [weak self] in
            let records = store.load(hours: hours)
            let error = store.error
            DispatchQueue.main.async { self?.records = records; self?.historyError = error }
        }
    }
    deinit { timer?.invalidate(); observers.forEach(NotificationCenter.default.removeObserver) }
}

func bytes(_ value: UInt64) -> String { value == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .binary) }
func rate(_ value: Double) -> String { bytes(UInt64(max(0, value.isFinite ? value : 0))) + "/s" }
