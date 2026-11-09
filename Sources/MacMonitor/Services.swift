import SwiftUI
import ServiceManagement

private struct LaunchJob: Identifiable {
    let id: String
    let pid: String
    let status: String
}
@MainActor private final class LaunchJobs: ObservableObject {
    @Published var jobs: [LaunchJob] = []
    @Published var message = tr("点击刷新以读取当前用户的 launchd 服务")
    @Published var busy = false
    func refresh() { run(["list"], list: true) }
    func control(_ job: LaunchJob, start: Bool) {
        guard !job.id.contains("/") else { message = tr("无效的服务名称"); return }
        let service = "gui/\(getuid())/\(job.id)"
        run(start ? ["kickstart", service] : ["kill", "SIGTERM", service], list: false)
    }
    private func run(_ arguments: [String], list: Bool) {
        guard !busy else { return }
        busy = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process(), pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = arguments; task.standardOutput = pipe; task.standardError = pipe
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self)
                let status = task.terminationStatus
                let jobs: [LaunchJob] = list && status == 0 ? text.split(separator: "\n").dropFirst().compactMap { line in
                    let fields = line.split(whereSeparator: { $0 == "\t" || $0 == " " }).map(String.init)
                    guard fields.count >= 3 else { return nil }
                    return LaunchJob(id: fields[2], pid: fields[0], status: fields[1])
                } : []
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.busy = false
                    if list && status == 0 { self.jobs = jobs; self.message = bilingual("\(jobs.count) 个当前用户服务", "\(jobs.count) services for this user") }
                    else if status == 0 { self.message = tr("命令已发送；服务可能根据配置自动重启。"); self.refresh() }
                    else { self.message = bilingual("操作失败（\(status)）：\(text.trimmingCharacters(in: .whitespacesAndNewlines))", "Operation failed (\(status)): \(text.trimmingCharacters(in: .whitespacesAndNewlines))") }
                }
            } catch { DispatchQueue.main.async { self?.busy = false; self?.message = bilingual("无法运行 launchctl：\(error.localizedDescription)", "Unable to run launchctl: \(error.localizedDescription)") } }
        }
    }
}
struct ServicesView: View {
    @StateObject private var model = LaunchJobs()
    @State private var query = ""
    @State private var pending: LaunchJob?
    @State private var start = false
    private var filtered: [LaunchJob] { model.jobs.filter { query.isEmpty || $0.id.localizedCaseInsensitiveContains(query) || $0.pid.contains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { TextField(tr("搜索服务名称或 PID"), text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 300); Button(tr("刷新")) { model.refresh() }.disabled(model.busy); Button(tr("系统登录项设置")) { SMAppService.openSystemSettingsLoginItems() }; Spacer(); if model.busy { ProgressView().controlSize(.small) } }
            Text(model.message).foregroundStyle(muted).font(.system(size: 11))
            Text(tr("仅显示当前用户 launchd 域中的服务，不代表系统设置中所有登录项。开始/停止操作受 macOS 权限和服务配置限制；停止后服务可能自动重启。")) .foregroundStyle(muted).font(.system(size: 11))
            Card { LazyVStack(spacing: 0) {
                HStack { Text(tr("服务")).frame(maxWidth: .infinity, alignment: .leading); Text("PID").frame(width: 70); Text(tr("上次退出状态")).frame(width: 90); Text("").frame(width: 110) }.foregroundStyle(muted).font(.system(size: 10))
                ForEach(filtered) { job in HStack {
                    Text(job.id).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    Text(job.pid).frame(width: 70); Text(job.status).frame(width: 90)
                    Button(job.pid == "-" ? tr("启动…") : tr("停止…")) { start = job.pid == "-"; pending = job }.disabled(model.busy).frame(width: 110)
                }.font(.system(size: 11)).padding(.vertical, 7); Divider() }
            } }
        }.onAppear { if model.jobs.isEmpty { model.refresh() } }
        .confirmationDialog(start ? tr("启动服务？") : tr("停止服务？"), isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { job in
            Button(start ? tr("启动") : tr("停止"), role: start ? nil : .destructive) { model.control(job, start: start); pending = nil }
            Button(tr("取消"), role: .cancel) { pending = nil }
        } message: { job in Text(bilingual("\(job.id)\n仅操作当前用户的服务；系统权限或服务配置可能阻止此操作。", "\(job.id)\nOnly the current user’s service is affected. System permissions or configuration may prevent this action.")) }
    }
}
