import SwiftUI
import Charts
import AppKit
import Darwin
import MonitorCore
import ServiceManagement
import Metal

private func bundledApplicationIcon() -> NSImage? {
    guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
    return NSImage(contentsOf: url)
}
final class MacFalconAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = bundledApplicationIcon() { NSApp.applicationIconImage = icon }
    }
}
@main struct MacMonitorApp: App {
    @NSApplicationDelegateAdaptor(MacFalconAppDelegate.self) private var appDelegate
    init() { SettingsMigration.migrate() }
    @StateObject private var monitor = Monitor()
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("accentColor") private var accentColor = "mint"
    var body: some Scene {
        WindowGroup("MacFalcon", id: "main") { ContentView().environmentObject(monitor).environment(\.locale, Locale(identifier: AppLanguage.resolve(appLanguage))).tint(paletteAccent(for: accentColor)).preferredColorScheme(selectedColorScheme(appearanceMode)).frame(minWidth: 960, minHeight: 640) }
            .windowStyle(.hiddenTitleBar)
            .commands { CommandGroup(after: .appInfo) { Button(tr("刷新数据")) { monitor.refresh() }.keyboardShortcut("r") } }
        MenuBarExtra("MacFalcon", systemImage: "waveform.path.ecg") { StatusMenu().environmentObject(monitor).environment(\.locale, Locale(identifier: AppLanguage.resolve(appLanguage))) }
    }
}

private enum Page: String, CaseIterable, Identifiable {
    case overview = "概览", processes = "进程", performance = "性能", network = "网络", diagnostics = "诊断", services = "服务", history = "历史", settings = "设置"
    var id: String { rawValue }
    var shortcut: KeyEquivalent { switch self { case .overview: return "1"; case .processes: return "2"; case .performance: return "3"; case .network: return "4"; case .diagnostics: return "5"; case .services: return "6"; case .history: return "7"; case .settings: return "8" } }
    var icon: String { switch self { case .overview: return "square.grid.2x2"; case .processes: return "square.stack.3d.up"; case .performance: return "waveform.path.ecg"; case .network: return "network"; case .diagnostics: return "stethoscope"; case .services: return "gearshape.2"; case .history: return "clock.arrow.circlepath"; case .settings: return "gearshape" } }
    var subtitle: String { switch self { case .overview: return tr("你的 Mac，尽在掌握"); case .processes: return tr("查看和管理正在运行的进程"); case .performance: return tr("实时了解系统资源的变化"); case .network: return tr("观察当前网络吞吐量"); case .diagnostics: return tr("按需查找端口和文件占用"); case .services: return tr("查看当前用户的后台服务"); case .history: return tr("回看最近七天的采样"); case .settings: return tr("按照你的节奏监控") } }
}

struct ContentView: View {
    @EnvironmentObject var monitor: Monitor
    @State private var page: Page = .overview
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView { Group {
                    switch page {
                    case .overview: OverviewView(showProcesses: { page = .processes })
                    case .processes: ProcessesView()
                    case .performance: PerformanceView()
                    case .network: NetworkView()
                    case .diagnostics: DiagnosticsView()
                    case .services: ServicesView()
                    case .history: HistoryView()
                    case .settings: SettingsView()
                    }
                }.padding(.horizontal, 32).padding(.bottom, 32).frame(maxWidth: .infinity, alignment: .leading) }
                .scrollIndicators(.automatic)
            }.background(canvas)
        }.foregroundStyle(Color.primary)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: bundledApplicationIcon() ?? NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) { Text("MACFALCON").font(.system(size: 14, weight: .bold, design: .rounded)).tracking(2); Text("SYSTEM MONITOR").font(.system(size: 8, weight: .semibold)).tracking(1.1).foregroundStyle(muted) }
            }.padding(.top, 52).padding(.horizontal, 22).padding(.bottom, 42)
            Text(tr("工作空间")).font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(muted).padding(.horizontal, 24).padding(.bottom, 12)
            ForEach(Page.allCases.filter { $0 != .settings }) { item in nav(item) }
            Spacer()
            nav(.settings)
            HStack(spacing: 9) { Circle().fill(monitor.isPaused ? orange : accent).frame(width: 7, height: 7); VStack(alignment: .leading, spacing: 3) { Text(monitor.isPaused ? tr("监控已暂停") : tr("系统监控中")).font(.system(size: 11, weight: .semibold)); Text(tr("本机 · 数据不会上传")).font(.system(size: 10)).foregroundStyle(muted) } }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).padding(16)
        }.frame(width: 210).background(sidebarColor)
    }
    private func nav(_ item: Page) -> some View {
        Button { page = item } label: {
            HStack(spacing: 12) { Image(systemName: item.icon).font(.system(size: 15, weight: .medium)).frame(width: 19); Text(tr(item.rawValue)).font(.system(size: 13, weight: page == item ? .semibold : .medium)); Spacer(); if page == item { Circle().fill(accent).frame(width: 5, height: 5) } }
                .foregroundStyle(page == item ? accent : Color.primary.opacity(0.58)).padding(.horizontal, 13).frame(height: 39).background(page == item ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).keyboardShortcut(item.shortcut, modifiers: .command).padding(.horizontal, 12).padding(.bottom, 3)
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) { Text(tr(page.rawValue)).font(.system(size: 27, weight: .semibold)); Text(page.subtitle).font(.system(size: 12)).foregroundStyle(muted) }
            Spacer()
            HStack(spacing: 8) { Circle().fill(monitor.isPaused ? orange : accent).frame(width: 6, height: 6); Text(monitor.isPaused ? tr("已暂停") : tr("实时监控")).font(.system(size: 11, weight: .medium)).foregroundStyle(muted) }.padding(.horizontal, 12).padding(.vertical, 8).background(panel, in: Capsule())
            Button { monitor.isPaused.toggle(); if !monitor.isPaused { monitor.refresh() } } label: { Image(systemName: monitor.isPaused ? "play.fill" : "pause.fill").frame(width: 30, height: 30) }.buttonStyle(.plain).background(panel, in: RoundedRectangle(cornerRadius: 8)).help(monitor.isPaused ? tr("恢复采样") : tr("暂停采样"))
        }.padding(.horizontal, 32).padding(.top, 39).padding(.bottom, 27)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.045))) }
}
struct SectionHeading: View {
    let title: String; var detail: String = ""
    var body: some View { HStack { Text(title).font(.system(size: 15, weight: .semibold)); Spacer(); Text(detail).font(.system(size: 11)).foregroundStyle(muted) } }
}
private struct MetricCard: View {
    let title: String; let value: String; let note: String; let icon: String; let color: Color; let points: [Double]
    var body: some View {
        Card { VStack(alignment: .leading, spacing: 15) {
            HStack { Image(systemName: icon).foregroundStyle(color).font(.system(size: 14)); Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(muted); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(muted.opacity(0.6)) }
            Text(value).font(.system(size: 25, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            HStack(alignment: .bottom) { Text(note).font(.system(size: 10)).foregroundStyle(muted).lineLimit(2).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 4); Sparkline(values: points, color: color).frame(width: 48, height: 25) }
        } }
    }
}
private struct Sparkline: View {
    let values: [Double]; let color: Color
    var body: some View { GeometryReader { geo in
        let maxValue = max(values.max() ?? 1, 1)
        Path { path in
            for (i, value) in values.enumerated() { let x = geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1)); let y = geo.size.height * (1 - CGFloat(value / maxValue)); if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) } }
        }.stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    } }
}
private func memoryUsed(_ s: Snapshot) -> UInt64 { min(s.memory.total, s.memory.active + s.memory.wired + s.memory.compressed) }
func percentage(_ x: Double) -> String { String(format: "%.1f%%", x) }

private struct OverviewView: View {
    @EnvironmentObject var monitor: Monitor
    let showProcesses: () -> Void
    var body: some View {
        let s = monitor.snapshot
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text(tr("系统概况")).font(.system(size: 16, weight: .semibold)); Text(tr("关键指标一览")).font(.system(size: 11)).foregroundStyle(muted) }; Spacer(); Text(bilingual("最近更新  \(s.sampledAt.formatted(date: .omitted, time: .standard))", "Updated  \(s.sampledAt.formatted(date: .omitted, time: .standard))")).font(.system(size: 10)).foregroundStyle(muted) }
            HStack(spacing: 12) {
                MetricCard(title: "CPU", value: percentage(s.cpu), note: tr("总处理器使用率"), icon: "cpu", color: accent, points: monitor.history.map(\.cpu))
                MetricCard(title: tr("内存"), value: bytes(memoryUsed(s)), note: bilingual("共 \(bytes(s.memory.total))", "of \(bytes(s.memory.total))"), icon: "memorychip", color: purple, points: monitor.history.map(\.memory))
                MetricCard(title: tr("下载"), value: rate(s.download), note: tr("所有活跃网络接口"), icon: "arrow.down", color: cyan, points: monitor.history.map(\.download))
                MetricCard(title: tr("上传"), value: rate(s.upload), note: tr("所有活跃网络接口"), icon: "arrow.up", color: orange, points: monitor.history.map(\.upload))
            }
            HStack(alignment: .top, spacing: 14) {
                Card { VStack(alignment: .leading, spacing: 16) { SectionHeading(title: tr("CPU 使用率"), detail: bilingual("最近 \(Int(monitor.interval) * max(0, monitor.history.count - 1)) 秒", "Last \(Int(monitor.interval) * max(0, monitor.history.count - 1)) seconds")); HistoryChart(samples: monitor.history, kind: .cpu).frame(height: 185); HStack { Label(tr("总使用率"), systemImage: "circle.fill").foregroundStyle(accent); Spacer(); Text(bilingual("\(ProcessInfo.processInfo.activeProcessorCount) 个逻辑核心", "\(ProcessInfo.processInfo.activeProcessorCount) logical cores")).foregroundStyle(muted) }.font(.system(size: 10)) } }.frame(maxWidth: .infinity)
                Card { VStack(alignment: .leading, spacing: 17) { SectionHeading(title: tr("系统信息"), detail: tr("此 Mac")); infoLine(tr("主机名称"), Host.current().localizedName ?? "Mac"); infoLine(tr("处理器核心"), bilingual("\(ProcessInfo.processInfo.activeProcessorCount) 个逻辑核心", "\(ProcessInfo.processInfo.activeProcessorCount) logical cores")); infoLine(tr("物理内存"), bytes(s.memory.total)); infoLine(tr("系统磁盘可用"), bytes(s.diskFree)); infoLine(tr("电池"), s.battery) } }.frame(width: 255)
            }
            Card { VStack(spacing: 0) { HStack { SectionHeading(title: tr("活跃进程"), detail: tr("按 CPU 使用率排序")); Button(tr("查看全部  →"), action: showProcesses).buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent).padding(.leading, 14) }.padding(.bottom, 15)
                ForEach(Array(s.processes.sorted { $0.cpu > $1.cpu }.prefix(5))) { p in
                    HStack(spacing: 12) { ProcessIcon(path: p.path, name: p.name); VStack(alignment: .leading, spacing: 3) { Text(p.name).font(.system(size: 12, weight: .medium)).lineLimit(1); Text("PID \(p.id)").font(.system(size: 10)).foregroundStyle(muted) }; Spacer(); Text(bytes(p.memory)).frame(width: 90, alignment: .trailing).foregroundStyle(muted); Text(percentage(p.cpu)).frame(width: 70, alignment: .trailing).foregroundStyle(accent) }.font(.system(size: 11, design: .monospaced)).padding(.vertical, 8)
                }
            } }
        }
    }
}
func infoLine(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(muted); Spacer(); Text(value).foregroundStyle(Color.primary.opacity(0.85)).lineLimit(1) }.font(.system(size: 11)) }
private let gpuName = MTLCreateSystemDefaultDevice()?.name ?? tr("不可用")
private let iconCache = NSCache<NSString, NSImage>()
private func processIcon(_ path: String) -> NSImage {
    if let cached = iconCache.object(forKey: path as NSString) { return cached }
    let image = NSWorkspace.shared.icon(forFile: path)
    iconCache.setObject(image, forKey: path as NSString)
    return image
}
private struct ProcessIcon: View {
    let path: String; let name: String
    var body: some View { Group { if !path.isEmpty { Image(nsImage: processIcon(path)).resizable().interpolation(.high) } else { Image(systemName: "terminal").foregroundStyle(muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6)) } }.frame(width: 28, height: 28).accessibilityLabel(name) }
}
private enum ChartKind { case cpu, memory, network }
private struct HistoryChart: View {
    let samples: [Sample]; let kind: ChartKind
    var body: some View {
        Chart {
            ForEach(samples) { sample in
                let value = kind == .cpu ? sample.cpu : kind == .memory ? sample.memory : sample.download
                LineMark(x: .value(tr("时间"), sample.time), y: .value(tr("数值"), value), series: .value(tr("方向"), tr("主要"))).foregroundStyle(kind == .memory ? purple : kind == .network ? cyan : accent).interpolationMethod(.linear)
                AreaMark(x: .value(tr("时间"), sample.time), y: .value(tr("数值"), value)).foregroundStyle((kind == .memory ? purple : kind == .network ? cyan : accent).opacity(0.08)).interpolationMethod(.linear)
                if kind == .network { LineMark(x: .value(tr("时间"), sample.time), y: .value(tr("上传"), sample.upload), series: .value(tr("方向"), tr("上传"))).foregroundStyle(orange).interpolationMethod(.linear) }
            }
        }.chartYScale(domain: kind == .network ? 0...max(1024, samples.map { max($0.download, $0.upload) }.max() ?? 0) : 0...100)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(muted); AxisGridLine().foregroundStyle(Color.primary.opacity(0.03)) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in AxisGridLine().foregroundStyle(Color.primary.opacity(0.07)); AxisValueLabel { if let number = value.as(Double.self) { Text(kind == .network ? rate(number) : "\(Int(number))%") .font(.system(size: 9)).foregroundStyle(muted) } } } }
    }
}

private enum ProcessSort: String, CaseIterable { case cpu = "CPU", memory = "内存", name = "名称", pid = "PID", read = "磁盘读取", write = "磁盘写入" }
private struct ProcessesView: View {
    @EnvironmentObject var monitor: Monitor
    @State private var query = ""
    @State private var sort: ProcessSort = .cpu
    @State private var viewMode = 0
    @State private var endTree = false
    @State private var force = false
    @State private var selectedCommand = ""
    @State private var selected: Int32?
    @State private var pending: ProcessInfoRow?
    @State private var errorMessage: String?
    private var filtered: [ProcessInfoRow] {
        monitor.snapshot.processes.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || String($0.id).contains(query) || $0.path.localizedCaseInsensitiveContains(query) }.sorted { a, b in
            switch sort { case .cpu: return a.cpu == b.cpu ? a.id < b.id : a.cpu > b.cpu; case .memory: return a.memory == b.memory ? a.id < b.id : a.memory > b.memory; case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending; case .pid: return a.id < b.id; case .read: return a.readRate > b.readRate; case .write: return a.writeRate > b.writeRate }
        }
    }
    private var ordered: [(row: ProcessInfoRow, depth: Int)] {
        let rows = filtered
        guard viewMode == 1 else { return rows.map { ($0, 0) } }
        let ids = Set(rows.map(\.id))
        let groups = Dictionary(grouping: rows, by: \.parent)
        var output: [(row: ProcessInfoRow, depth: Int)] = []
        var seen = Set<Int32>()
        func append(_ row: ProcessInfoRow, _ depth: Int) {
            guard seen.insert(row.id).inserted else { return }
            output.append((row, min(depth, 12)))
            for child in groups[row.id] ?? [] { append(child, depth + 1) }
        }
        for row in rows where !ids.contains(row.parent) || row.parent == row.id { append(row, 0) }
        for row in rows { append(row, 0) }
        return output
    }
    private var grouped: [(key: String, rows: [ProcessInfoRow])] {
        let groups = Dictionary(grouping: filtered) { row -> String in
            if let range = row.path.range(of: ".app/", options: .caseInsensitive) { return String(row.path[..<range.upperBound].dropLast()) }
            return row.path.isEmpty ? row.name : row.path
        }
        return groups.map { (key: $0.key, rows: $0.value) }.sorted { a, b in
            if sort == .name { return a.key.localizedStandardCompare(b.key) == .orderedAscending }
            if sort == .pid { return (a.rows.map(\.id).min() ?? 0) < (b.rows.map(\.id).min() ?? 0) }
            func value(_ rows: [ProcessInfoRow]) -> Double {
                rows.reduce(0) { sum, row in
                    switch sort { case .cpu: return sum + row.cpu; case .memory: return sum + Double(row.memory); case .read: return sum + row.readRate; case .write: return sum + row.writeRate; default: return sum }
                }
            }
            let left = value(a.rows), right = value(b.rows)
            return left == right ? a.key < b.key : left > right
        }
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack { HStack { Image(systemName: "magnifyingglass").foregroundStyle(muted); TextField(tr("搜索名称、PID 或路径"), text: $query).textFieldStyle(.plain) }.padding(10).background(panel, in: RoundedRectangle(cornerRadius: 9)).frame(maxWidth: 310)
                Spacer(); Picker(tr("视图"), selection: $viewMode) { Text(tr("列表")).tag(0); Text(tr("进程树")).tag(1); Text(tr("应用")).tag(2) }.labelsHidden().frame(width: 110); Text(bilingual("\(filtered.count) 个进程", "\(filtered.count) processes")).font(.system(size: 11)).foregroundStyle(muted); Picker(tr("排序"), selection: $sort) { ForEach(ProcessSort.allCases, id: \.self) { Text(tr($0.rawValue)).tag($0) } }.frame(width: 130)
            }
            Card { VStack(spacing: 0) {
                HStack { Text(tr("进程 / PID")).frame(maxWidth: .infinity, alignment: .leading); Text("CPU").frame(width: 70, alignment: .trailing); Text(tr("内存")).frame(width: 90, alignment: .trailing); Text(tr("读取 / 秒")).frame(width: 90, alignment: .trailing); Text(tr("写入 / 秒")).frame(width: 90, alignment: .trailing); Text("").frame(width: 28) }.font(.system(size: 10, weight: .semibold)).foregroundStyle(muted).padding(.bottom, 12)
                Divider().overlay(Color.primary.opacity(0.06))
                LazyVStack(spacing: 0) {
                    if viewMode == 2 {
                        ForEach(grouped, id: \.key) { group in
                            DisclosureGroup {
                                ForEach(group.rows) { row in processRow(row, depth: 1) }
                            } label: {
                                HStack {
                                    ProcessIcon(path: group.key, name: group.key)
                                    VStack(alignment: .leading, spacing: 3) { Text(URL(fileURLWithPath: group.key).deletingPathExtension().lastPathComponent).lineLimit(1); Text(bilingual("\(group.rows.count) 个进程", "\(group.rows.count) processes")).font(.system(size: 10)).foregroundStyle(muted) }.frame(maxWidth: .infinity, alignment: .leading)
                                    Text(percentage(group.rows.reduce(0) { $0 + $1.cpu })).frame(width: 70, alignment: .trailing)
                                    Text(bytes(group.rows.reduce(0) { $0 + $1.memory })).frame(width: 90, alignment: .trailing)
                                    Text(group.rows.allSatisfy(\.ioAvailable) ? rate(group.rows.reduce(0) { $0 + $1.readRate }) : "—").frame(width: 90, alignment: .trailing)
                                    Text(group.rows.allSatisfy(\.ioAvailable) ? rate(group.rows.reduce(0) { $0 + $1.writeRate }) : "—").frame(width: 90, alignment: .trailing)
                                }.font(.system(size: 11)).padding(.vertical, 9)
                            }
                            Divider().overlay(Color.primary.opacity(0.035))
                        }
                    } else {
                        ForEach(ordered, id: \.row.id) { item in processRow(item.row, depth: item.depth) }
                    }
                }
                if filtered.isEmpty { Text(tr("没有找到匹配的进程")).font(.system(size: 12)).foregroundStyle(muted).frame(maxWidth: .infinity).padding(35) }
            } }
            Text(tr("CPU 可超过 100%，表示进程同时使用多个核心。磁盘速率为进程累计读写量的采样差值；权限不足时可能不可用。")).font(.system(size: 10)).foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog(bilingual("结束进程 \(pending?.name ?? "")？", "End process \(pending?.name ?? "")?"), isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible, presenting: pending) { process in
            Button(force ? tr("强制结束") : (endTree ? tr("结束进程树") : tr("结束进程")), role: .destructive) { terminate(process) }
            Button(tr("取消"), role: .cancel) { pending = nil }
        } message: { process in Text(force ? bilingual("将向 PID \(process.id) 发送强制终止信号。未保存的数据可能会丢失。", "PID \(process.id) will be force quit. Unsaved data may be lost.") : endTree ? tr("将向当前快照中该进程及其后代发送终止信号。未保存的数据可能会丢失。") : bilingual("将向 PID \(process.id) 发送终止信号。未保存的数据可能会丢失。", "A termination signal will be sent to PID \(process.id). Unsaved data may be lost.")) }
        .alert(tr("无法结束进程"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button(tr("好")) { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }
    private func processRow(_ p: ProcessInfoRow, depth: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if depth > 0 { Color.clear.frame(width: CGFloat(depth) * 14, height: 1) }
                ProcessIcon(path: p.path, name: p.name)
                VStack(alignment: .leading, spacing: 3) { Text(p.name).font(.system(size: 12, weight: .medium)).lineLimit(1); Text("PID \(p.id)").font(.system(size: 10)).foregroundStyle(muted) }.frame(maxWidth: .infinity, alignment: .leading)
                Text(percentage(p.cpu)).foregroundStyle(p.cpu > 10 ? accent : Color.primary.opacity(0.8)).frame(width: 70, alignment: .trailing)
                Text(bytes(p.memory)).frame(width: 90, alignment: .trailing)
                Text(p.ioAvailable ? rate(p.readRate) : "—").frame(width: 90, alignment: .trailing)
                Text(p.ioAvailable ? rate(p.writeRate) : "—").frame(width: 90, alignment: .trailing)
                Image(systemName: selected == p.id ? "chevron.up" : "chevron.down").foregroundStyle(muted).frame(width: 28)
            }.font(.system(size: 11, design: .monospaced)).padding(.vertical, 9).contentShape(Rectangle()).onTapGesture { selected = selected == p.id ? nil : p.id }
            if selected == p.id { processDetails(p).task(id: "\(p.id)-\(p.startTime)") {
                selectedCommand = tr("正在读取…")
                let value = await Task.detached(priority: .utility) { () -> String in
                    var buffer = [CChar](repeating: 0, count: 16384)
                    return mm_process_arguments(p.id, p.startTime, &buffer, buffer.count) != 0 ? String(cString: buffer) : tr("不可用（系统权限限制或进程已退出）")
                }.value
                if selected == p.id { selectedCommand = value }
            } }
            Divider().overlay(Color.primary.opacity(0.035))
        }
    }
    private func processDetails(_ p: ProcessInfoRow) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            infoLine(tr("可执行文件"), p.path.isEmpty ? tr("不可用（系统权限限制）") : p.path)
            VStack(alignment: .leading, spacing: 4) { Text(tr("启动参数")).foregroundStyle(muted); Text(selectedCommand).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.font(.system(size: 11))
            infoLine(tr("父进程 / 用户 ID"), "\(p.parent) / \(p.uid)")
            infoLine(tr("线程 / 虚拟内存"), "\(p.threads) / \(bytes(p.virtualMemory))")
            HStack {
                if !p.path.isEmpty { Button(tr("在访达中显示")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p.path)]) } }
                Menu(tr("优先级")) { Button(tr("正常 (nice 0)")) { changePriority(p, 0) }; Button(tr("较低 (nice 10)")) { changePriority(p, 10) }; Button(tr("最低 (nice 19)")) { changePriority(p, 19) }; Divider(); Button(tr("每次启动时设为较低")) { monitor.setRule(path: p.path, nice: 10) }.disabled(p.path.isEmpty); Button(tr("每次启动时设为最低")) { monitor.setRule(path: p.path, nice: 19) }.disabled(p.path.isEmpty) }
                Spacer(); Button(tr("结束进程树…")) { force = false; endTree = true; pending = p }.disabled(p.id <= 1 || p.id == getpid()).foregroundStyle(orange)
                Button(tr("结束进程…")) { force = false; endTree = false; pending = p }.disabled(p.id == 1 || p.id == getpid()).foregroundStyle(orange)
                Button(tr("强制结束…")) { force = true; endTree = false; pending = p }.disabled(p.id <= 1 || p.id == getpid()).foregroundStyle(orange) }
        }.padding(12).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8)).padding(.bottom, 8).textSelection(.enabled)
    }
    private func changePriority(_ p: ProcessInfoRow, _ priority: Int32) {
        guard p.id > 1, p.id != getpid(), mm_process_matches(p.id, p.startTime) != 0 else { errorMessage = tr("进程已退出或发生变化。"); return }
        if setpriority(PRIO_PROCESS, id_t(p.id), priority) != 0 { errorMessage = String(cString: strerror(errno)) }
    }
    private func terminate(_ p: ProcessInfoRow) {
        defer { pending = nil }
        guard p.id > 1, p.id != getpid(), mm_process_matches(p.id, p.startTime) != 0 else { errorMessage = tr("进程已退出或发生变化，请刷新后重试。"); return }
        var targets: [ProcessInfoRow] = []
        let groups = Dictionary(grouping: monitor.snapshot.processes, by: \.parent)
        var seen = Set<Int32>()
        func collect(_ process: ProcessInfoRow) {
            guard seen.insert(process.id).inserted else { return }
            if endTree { for child in groups[process.id] ?? [] { collect(child) } }
            targets.append(process)
        }
        collect(p)
        var failed = 0
        for target in targets where target.id > 1 && target.id != getpid() {
            if mm_process_matches(target.id, target.startTime) == 0 || kill(target.id, force ? SIGKILL : SIGTERM) != 0 { failed += 1 }
        }
        if failed > 0 { errorMessage = bilingual("\(failed) 个进程已退出或无权结束。", "\(failed) processes exited or could not be ended due to permissions.") }
        monitor.refresh()
    }
}
private struct PerformanceView: View {
    @EnvironmentObject var monitor: Monitor
    var body: some View { let s = monitor.snapshot; VStack(spacing: 14) {
        Card { VStack(alignment: .leading, spacing: 15) { SectionHeading(title: tr("处理器"), detail: bilingual("\(ProcessInfo.processInfo.activeProcessorCount) 个逻辑核心", "\(ProcessInfo.processInfo.activeProcessorCount) logical cores")); HStack(alignment: .firstTextBaseline) { Text(percentage(s.cpu)).font(.system(size: 32, weight: .semibold, design: .rounded)); Text(tr("总使用率")).font(.system(size: 11)).foregroundStyle(muted) }; HistoryChart(samples: monitor.history, kind: .cpu).frame(height: 170); if !s.coreUsage.isEmpty { LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 10) { ForEach(Array(s.coreUsage.enumerated()), id: \.offset) { index, value in VStack(alignment: .leading, spacing: 5) { infoLine(bilingual("核心 \(index)", "Core \(index)"), percentage(value)); ProgressView(value: value, total: 100).tint(accent) } } } } } }
        Card { VStack(alignment: .leading, spacing: 15) { SectionHeading(title: tr("内存"), detail: bilingual("物理内存 \(bytes(s.memory.total))", "Physical memory \(bytes(s.memory.total))")); HStack(alignment: .firstTextBaseline) { Text(bytes(memoryUsed(s))).font(.system(size: 32, weight: .semibold, design: .rounded)); Text(tr("活跃 + 已连接 + 已压缩")).font(.system(size: 11)).foregroundStyle(muted) }; HistoryChart(samples: monitor.history, kind: .memory).frame(height: 170); HStack { infoLine(tr("活跃"), bytes(s.memory.active)); Spacer().frame(width: 30); infoLine(tr("已连接"), bytes(s.memory.wired)); Spacer().frame(width: 30); infoLine(tr("已压缩"), bytes(s.memory.compressed)); Spacer().frame(width: 30); infoLine(tr("空闲"), bytes(s.memory.free)) }; infoLine(tr("交换空间已用 / 总量"), "\(bytes(s.memory.swap_used)) / \(bytes(s.memory.swap_total))") } }
        Card { VStack(alignment: .leading, spacing: 15) { SectionHeading(title: tr("图形处理器与电源"), detail: tr("系统可用信息")); infoLine("GPU", gpuName); infoLine(tr("GPU 利用率"), s.hardware.gpu_available != 0 ? "\(s.hardware.gpu_percent)%" : tr("不可用")); infoLine(tr("电池"), s.battery); if s.hardware.battery_available != 0 { infoLine(tr("充电循环"), bilingual("\(s.hardware.cycle_count) 次", "\(s.hardware.cycle_count) cycles")); infoLine(tr("估算最大容量 / 设计容量"), String(format: "%.1f%%", Double(s.hardware.max_capacity) / Double(s.hardware.design_capacity) * 100)) }; Text(tr("GPU 利用率和电池容量来自设备注册表，取决于机型，可能与系统估算不同；温度和功耗暂不可用。")) .font(.system(size: 11)).foregroundStyle(muted) } }
        Card { VStack(alignment: .leading, spacing: 15) { SectionHeading(title: tr("系统磁盘"), detail: tr("用户主目录所在宗卷")); infoLine(tr("可用 / 总容量"), "\(bytes(s.diskFree)) / \(bytes(s.diskTotal))"); infoLine(tr("所有可见磁盘读取 / 写入"), "\(s.diskReadRate.map(rate) ?? "—") / \(s.diskWriteRate.map(rate) ?? "—")"); GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.primary.opacity(0.06)); Capsule().fill(cyan).frame(width: geo.size.width * CGFloat(s.diskTotal > 0 ? Double(s.diskTotal - min(s.diskFree, s.diskTotal)) / Double(s.diskTotal) : 0)) } }.frame(height: 7) } }
    } }
}
private struct NetworkView: View {
    @EnvironmentObject var monitor: Monitor
    var body: some View { VStack(spacing: 14) {
        HStack(spacing: 14) { MetricCard(title: tr("下载速率"), value: rate(monitor.snapshot.download), note: tr("所有活跃网络接口"), icon: "arrow.down", color: cyan, points: monitor.history.map(\.download)); MetricCard(title: tr("上传速率"), value: rate(monitor.snapshot.upload), note: tr("所有活跃网络接口"), icon: "arrow.up", color: orange, points: monitor.history.map(\.upload)) }
        Card { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: tr("网络吞吐量"), detail: tr("按采样间隔计算")); HistoryChart(samples: monitor.history, kind: .network).frame(height: 260); HStack(spacing: 20) { Label(tr("下载"), systemImage: "circle.fill").foregroundStyle(cyan); Label(tr("上传"), systemImage: "circle.fill").foregroundStyle(orange) }.font(.system(size: 10)); Text(tr("统计活跃的非回环网络接口。VPN 或虚拟接口可能使同一流量被重复计数。")) .font(.system(size: 11)).foregroundStyle(muted) } }
    } }
}
private struct StatusMenu: View {
    @EnvironmentObject var monitor: Monitor
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(bilingual("CPU \(percentage(monitor.snapshot.cpu)) · 内存 \(bytes(memoryUsed(monitor.snapshot)))", "CPU \(percentage(monitor.snapshot.cpu)) · Memory \(bytes(memoryUsed(monitor.snapshot)))"))
        Text(monitor.backgroundHistory ? tr("窗口隐藏时每分钟更新") : tr("数据在窗口隐藏时暂停更新"))
        Divider()
        Button(tr("打开 MacFalcon")) { NSApp.activate(ignoringOtherApps: true); openWindow(id: "main") }
        Button(monitor.isPaused ? tr("恢复采样") : tr("暂停采样")) { monitor.isPaused.toggle(); if !monitor.isPaused { monitor.refresh() } }
        Divider()
        Button(tr("退出 MacFalcon")) { NSApp.terminate(nil) }
    }
}
private struct SettingsView: View {
    @EnvironmentObject var monitor: Monitor
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?
    @State private var confirmClear = false
    var body: some View { VStack(spacing: 14) {
        AppearanceSettings()
        Card { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: tr("采样"), detail: tr("资源占用")); HStack { VStack(alignment: .leading, spacing: 5) { Text(tr("刷新间隔")).font(.system(size: 13, weight: .medium)); Text(tr("较长的间隔可以进一步降低资源占用。")).font(.system(size: 11)).foregroundStyle(muted) }; Spacer(); Picker(tr("刷新间隔"), selection: $monitor.interval) { Text(tr("1 秒")).tag(1.0); Text(tr("3 秒")).tag(3.0); Text(tr("5 秒")).tag(5.0); Text(tr("10 秒")).tag(10.0) }.labelsHidden().frame(width: 110) }; Divider(); Toggle(tr("窗口隐藏时每分钟记录历史"), isOn: $monitor.backgroundHistory).toggleStyle(.checkbox)
            infoLine(tr("历史记录"), tr("每分钟最多记录一次，保留 7 天")) } }
        Card { VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: tr("登录与后台"), detail: tr("由 macOS 管理"))
            infoLine(tr("登录时打开"), loginStatus == .enabled ? tr("已启用") : loginStatus == .requiresApproval ? tr("等待系统批准") : tr("未启用"))
            HStack { Button(loginStatus == .enabled ? tr("关闭登录启动") : tr("启用登录启动")) { do { if loginStatus == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }; loginStatus = SMAppService.mainApp.status } catch { loginError = error.localizedDescription; loginStatus = SMAppService.mainApp.status } }; Button(tr("打开系统登录项设置")) { SMAppService.openSystemSettingsLoginItems() } }
            Text(tr("菜单栏可重新打开窗口或退出应用。登录启动需要从已安装的应用包运行，并可能需要系统批准。")) .font(.system(size: 11)).foregroundStyle(muted)
            if let loginError { Text(loginError).foregroundStyle(orange).font(.system(size: 11)) }
        } }
        Card { VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: tr("优先级规则"), detail: tr("按可执行文件路径匹配"))
            Text(tr("进程启动后尝试设置一次 nice 值；系统权限可能阻止操作。移除规则不会恢复已运行进程的优先级。")) .font(.system(size: 11)).foregroundStyle(muted)
            if !monitor.ruleFailures.isEmpty { HStack { Text(bilingual("最近一次规则执行失败：\(monitor.ruleFailures.joined(separator: "；"))", "Latest rule failures: \(monitor.ruleFailures.joined(separator: "; "))")).foregroundStyle(orange).font(.system(size: 11)); Spacer(); Button(tr("忽略")) { monitor.ruleFailures = [] } } }
            if monitor.priorityRules.isEmpty { Text(tr("暂无规则。可在进程详情中添加。")) .font(.system(size: 11)).foregroundStyle(muted) }
            ForEach(monitor.priorityRules) { rule in HStack { Text(rule.path).lineLimit(1).textSelection(.enabled); Spacer(); Text("nice \(rule.nice)").foregroundStyle(muted); Button(tr("移除")) { monitor.priorityRules.removeAll { $0.id == rule.id } } }.font(.system(size: 11)) }
            Divider()
            HStack { Text(tr("历史数据保存在本机")).font(.system(size: 11)).foregroundStyle(muted); Spacer(); Button(tr("清除历史…")) { confirmClear = true } }
        } }
        Card { VStack(alignment: .leading, spacing: 14) { SectionHeading(title: tr("关于 MacFalcon"), detail: tr("原生 macOS 系统监视器")); Text(tr("使用 macOS 原生接口采样，数据仅保留在本机。部分受保护的进程信息可能因系统权限而不可用。")) .font(.system(size: 12)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true); infoLine(tr("版本"), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0") } }
    }.confirmationDialog(tr("清除全部历史记录？"), isPresented: $confirmClear, titleVisibility: .visible) { Button(tr("清除历史"), role: .destructive) { monitor.clearHistory() }; Button(tr("取消"), role: .cancel) {} } message: { Text(tr("此操作会删除本机保存的采样和进程快照。")) } }
}
