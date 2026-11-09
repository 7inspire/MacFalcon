import SwiftUI
import AppKit

struct DiagnosticEntry: Identifiable {
    let id = UUID()
    var pid = ""
    var command = ""
    var descriptor = ""
    var proto = ""
    var name = ""
    var state = ""
}

// lsof emits NUL-delimited fields; a process record is followed by file records.
func parseLsof(_ data: Data) -> [DiagnosticEntry] {
    var result: [DiagnosticEntry] = []
    var pid = "", command = ""
    var current: DiagnosticEntry?
    func append() { if let row = current, !row.name.isEmpty { result.append(row) }; current = nil }
    for raw in data.split(separator: 0) {
        let field = String(decoding: raw, as: UTF8.self).drop(while: { $0 == "\n" })
        guard let key = field.first else { continue }
        let value = String(field.dropFirst())
        switch key {
        case "p": append(); pid = value; command = ""
        case "c": command = value
        case "f": append(); current = DiagnosticEntry(pid: pid, command: command, descriptor: value)
        case "P": current?.proto = value
        case "n": current?.name = value
        case "T": if value.hasPrefix("ST=") { current?.state = String(value.dropFirst(3)) }
        default: break
        }
    }
    append()
    return result
}

@MainActor final class DiagnosticScanner: ObservableObject {
    @Published var rows: [DiagnosticEntry] = []
    @Published var working = false
    @Published var message = tr("点击扫描后显示结果")
    private var task: Process?
    private var generation = UUID()
    func scan(path: URL? = nil, recursive: Bool = false) {
        guard !working else { return }
        let process = Process(), output = Pipe(), errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        var arguments = ["-nP", "-F0pcfnPT"]
        if let path {
            if recursive { arguments += ["+D", path.path] }
            else { arguments += ["--", path.path] }
        } else { arguments += ["-iTCP", "-iUDP"] }
        process.arguments = arguments; process.standardOutput = output; process.standardError = errors
        do { try process.run() } catch { message = bilingual("无法启动扫描：\(error.localizedDescription)", "Unable to start scan: \(error.localizedDescription)"); return }
        rows = []; working = true; message = tr("正在扫描…"); task = process
        let token = UUID(); generation = token
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Drain stderr independently to prevent a full pipe blocking lsof.
            let group = DispatchGroup(); group.enter()
            DispatchQueue.global(qos: .utility).async { _ = errors.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            var data = Data(); var limited = false
            while true {
                let chunk = output.fileHandleForReading.readData(ofLength: 64 * 1024)
                if chunk.isEmpty { break }
                data.append(chunk)
                if data.count > 8 * 1024 * 1024 { limited = true; if process.isRunning { process.terminate() }; break }
            }
            process.waitUntilExit(); group.wait()
            let parsed = parseLsof(data)
            let status = process.terminationStatus
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.rows = parsed; self.working = false; self.task = nil
                self.message = limited ? tr("结果超过 8 MB，已截断；缩小查询范围。") : status == 0 ? bilingual("找到 \(parsed.count) 条记录；权限限制可能隐藏其他进程。", "Found \(parsed.count) records; permissions may hide other processes.") : status == 1 && parsed.isEmpty ? tr("没有找到可访问的记录；受保护的进程可能不可见。") : bilingual("扫描结束（状态 \(status)），结果可能不完整。", "Scan finished (status \(status)); results may be incomplete.")
            }
        }
    }
    func cancel() { generation = UUID(); if task?.isRunning == true { task?.terminate() }; task = nil; working = false; message = tr("已取消扫描") }
}

struct DiagnosticsView: View {
    @StateObject private var scanner = DiagnosticScanner()
    @State private var mode = 0
    @State private var filter = ""
    @State private var recursive = false
    @State private var path: URL?
    private var filtered: [DiagnosticEntry] { scanner.rows.filter { filter.isEmpty || "\($0.pid) \($0.command) \($0.proto) \($0.name) \($0.state)".localizedCaseInsensitiveContains(filter) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker(tr("诊断类型"), selection: $mode) { Text(tr("连接与端口")).tag(0); Text(tr("文件占用")).tag(1) }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                Spacer()
                if scanner.working { Button(tr("取消")) { scanner.cancel() } }
                else { Button(tr("开始扫描")) { scanner.scan(path: mode == 1 ? path : nil, recursive: mode == 1 && recursive && (path?.hasDirectoryPath ?? false)) }.disabled(mode == 1 && path == nil) }
            }
            if mode == 1 {
                HStack {
                    Button(tr("选择文件或文件夹…")) { let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; if panel.runModal() == .OK { path = panel.url } }
                    Toggle(tr("递归文件夹"), isOn: $recursive).toggleStyle(.checkbox)
                }
            }
            if let path, mode == 1 { Text(path.path).font(.system(size: 11)).foregroundStyle(muted).textSelection(.enabled) }
            TextField(tr("筛选进程、PID、端口或路径"), text: $filter).textFieldStyle(.roundedBorder).frame(maxWidth: 320)
            Text(scanner.message).foregroundStyle(muted).font(.system(size: 11))
            Card { VStack(alignment: .leading, spacing: 0) {
                HStack { Text(tr("进程 / PID")).frame(width: 170, alignment: .leading); Text(tr("协议 / FD")).frame(width: 100, alignment: .leading); Text(tr("地址或文件")).frame(maxWidth: .infinity, alignment: .leading); Text(tr("状态")).frame(width: 90, alignment: .leading) }.font(.system(size: 10, weight: .semibold)).foregroundStyle(muted).padding(.bottom, 10)
                Divider()
                LazyVStack(spacing: 0) { ForEach(filtered) { row in
                    HStack { VStack(alignment: .leading) { Text(row.command).lineLimit(1); Text("PID \(row.pid)").foregroundStyle(muted) }.frame(width: 170, alignment: .leading); Text(row.proto.isEmpty ? row.descriptor : row.proto).frame(width: 100, alignment: .leading); Text(row.name).frame(maxWidth: .infinity, alignment: .leading).lineLimit(2).textSelection(.enabled); Text(row.state).frame(width: 90, alignment: .leading) }.font(.system(size: 11)).padding(.vertical, 8); Divider()
                } }
                if filtered.isEmpty { Text(scanner.working ? tr("扫描中…") : tr("没有记录")).foregroundStyle(muted).padding(20).frame(maxWidth: .infinity) }
            } }
            Text(tr("使用系统 lsof 按需扫描；不提升权限。文件夹递归扫描可能较慢，可随时取消。端口连接仅供查看，macOS 不提供通用的安全断开接口。")) .font(.system(size: 11)).foregroundStyle(muted)
        }.onDisappear { if scanner.working { scanner.cancel() } }
    }
}

struct HistoryView: View {
    @EnvironmentObject var monitor: Monitor
    @State private var hours = 24
    @State private var selected: Int64?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Picker(tr("时间范围"), selection: $hours) { Text(tr("最近 1 小时")).tag(1); Text(tr("最近 24 小时")).tag(24); Text(tr("最近 7 天")).tag(168) }.pickerStyle(.segmented).frame(width: 310); Button(tr("刷新")) { monitor.loadHistory(hours: hours) }; Spacer(); Text(bilingual("\(monitor.records.count) 条采样", "\(monitor.records.count) samples")).font(.system(size: 11)).foregroundStyle(muted) }
            if let error = monitor.historyError { Text(bilingual("历史记录不可用：\(error)", "History unavailable: \(error)")).foregroundStyle(orange) }
            Text(tr("每分钟最多记录一次，保存 7 天；监控暂停时不会采集；隐藏窗口时默认暂停，可在设置中启用后台采样。选择记录可查看当时 CPU 最活跃的进程。")) .font(.system(size: 11)).foregroundStyle(muted)
            Card { LazyVStack(spacing: 0) {
                HStack { Text(tr("时间")).frame(width: 150, alignment: .leading); Text("CPU").frame(width: 80, alignment: .trailing); Text(tr("内存")).frame(width: 80, alignment: .trailing); Text(tr("下载")).frame(width: 110, alignment: .trailing); Text(tr("上传")).frame(width: 110, alignment: .trailing); Spacer() }.font(.system(size: 10, weight: .semibold)).foregroundStyle(muted)
                ForEach(monitor.records) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(row.time.formatted(date: .abbreviated, time: .shortened)).frame(width: 150, alignment: .leading); Text(percentage(row.cpu)).frame(width: 80, alignment: .trailing); Text(percentage(row.memory)).frame(width: 80, alignment: .trailing); Text(rate(row.download)).frame(width: 110, alignment: .trailing); Text(rate(row.upload)).frame(width: 110, alignment: .trailing); Spacer(); Image(systemName: selected == row.id ? "chevron.up" : "chevron.down") }.font(.system(size: 11)).contentShape(Rectangle()).onTapGesture { selected = selected == row.id ? nil : row.id }
                        if selected == row.id { ForEach(row.processes) { p in infoLine("\(p.name) · PID \(p.id)", "CPU \(percentage(p.cpu)) · \(bytes(p.memory))") } }
                        Divider()
                    }.padding(.top, 10)
                }
                if monitor.records.isEmpty { Text(tr("暂时没有历史记录")).foregroundStyle(muted).padding(25).frame(maxWidth: .infinity) }
            } }
        }.onAppear { monitor.loadHistory(hours: hours) }.onChange(of: hours) { monitor.loadHistory(hours: $0) }
    }
}
