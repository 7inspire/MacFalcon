import SwiftUI
import AppKit

func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
}
private func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
let canvas = adaptiveColor(light: rgb(0.96, 0.97, 0.97), dark: rgb(0.055, 0.067, 0.073))
let sidebarColor = adaptiveColor(light: rgb(0.92, 0.94, 0.94), dark: rgb(0.072, 0.085, 0.092))
let panel = adaptiveColor(light: rgb(1, 1, 1), dark: rgb(0.092, 0.109, 0.116))
let muted = adaptiveColor(light: rgb(0.34, 0.39, 0.40), dark: rgb(0.62, 0.67, 0.68))
let cyan = adaptiveColor(light: rgb(0.11, 0.40, 0.70), dark: rgb(0.43, 0.72, 0.96))
let purple = adaptiveColor(light: rgb(0.43, 0.31, 0.70), dark: rgb(0.73, 0.62, 0.96))
let orange = adaptiveColor(light: rgb(0.67, 0.37, 0.10), dark: rgb(0.96, 0.72, 0.43))
var accent: Color { paletteAccent(for: UserDefaults.standard.string(forKey: "accentColor") ?? "mint") }
func paletteAccent(for selected: String) -> Color {
    switch selected {
    case "blue": return adaptiveColor(light: rgb(0.12, 0.35, 0.76), dark: rgb(0.47, 0.69, 1))
    case "purple": return adaptiveColor(light: rgb(0.44, 0.29, 0.72), dark: rgb(0.76, 0.65, 0.98))
    case "orange": return adaptiveColor(light: rgb(0.67, 0.34, 0.08), dark: rgb(0.98, 0.70, 0.41))
    default: return adaptiveColor(light: rgb(0.05, 0.43, 0.32), dark: rgb(0.42, 0.87, 0.70))
    }
}
func selectedColorScheme(_ mode: String) -> ColorScheme? {
    switch mode { case "light": return .light; case "dark": return .dark; default: return nil }
}

struct AppearanceSettings: View {
    @AppStorage("appearanceMode") private var mode = "system"
    @AppStorage("accentColor") private var color = "mint"
    @AppStorage("appLanguage") private var language = "system"
    private let colors: [(String, String)] = [("mint", "薄荷绿"), ("blue", "蓝色"), ("purple", "紫色"), ("orange", "橙色")]
    var body: some View {
        Card { VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: tr("外观"), detail: tr("视觉风格与语言"))
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) { Text(tr("模式")).font(.system(size: 13, weight: .medium)); Text(tr("选择浅色、深色或跟随系统。" )).font(.system(size: 11)).foregroundStyle(muted) }
                Spacer()
                HStack(spacing: 10) {
                    modeButton("system", title: tr("跟随系统"))
                    modeButton("light", title: tr("浅色"))
                    modeButton("dark", title: tr("深色"))
                }
            }
            Divider()
            HStack { VStack(alignment: .leading, spacing: 5) { Text(tr("强调色")).font(.system(size: 13, weight: .medium)); Text(tr("用于选中状态、按钮和图表。" )).font(.system(size: 11)).foregroundStyle(muted) }; Spacer()
                HStack(spacing: 12) { ForEach(colors, id: \.0) { item in
                    Button { color = item.0 } label: { ZStack { Circle().fill(swatch(item.0)).frame(width: 24, height: 24); if color == item.0 { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) } }.frame(width: 32, height: 32).overlay(Circle().stroke(color == item.0 ? accent : Color.clear, lineWidth: 1.5)) }.buttonStyle(.plain).help(tr(item.1)).accessibilityLabel(tr(item.1)).accessibilityAddTraits(color == item.0 ? .isSelected : [])
                } }
            }
            Divider()
            HStack { VStack(alignment: .leading, spacing: 5) { Text(tr("语言")).font(.system(size: 13, weight: .medium)); Text(tr("更改立即生效。" )).font(.system(size: 11)).foregroundStyle(muted) }; Spacer(); Picker(tr("语言"), selection: $language) { Text(tr("跟随系统")).tag("system"); Text("简体中文").tag("zh-Hans"); Text("English").tag("en") }.labelsHidden().frame(width: 150) }
        } }
    }
    private func swatch(_ key: String) -> Color {
        switch key { case "blue": return Color(red: 0.22, green: 0.46, blue: 0.88); case "purple": return Color(red: 0.59, green: 0.43, blue: 0.84); case "orange": return Color(red: 0.82, green: 0.47, blue: 0.15); default: return Color(red: 0.13, green: 0.63, blue: 0.47) }
    }
    private func modeButton(_ key: String, title: String) -> some View {
        Button { mode = key } label: {
            VStack(spacing: 6) {
                ZStack { RoundedRectangle(cornerRadius: 8).fill(key == "dark" ? Color(red: 0.10, green: 0.12, blue: 0.13) : Color(red: 0.93, green: 0.94, blue: 0.94))
                    HStack(spacing: 0) { RoundedRectangle(cornerRadius: 2).fill(key == "dark" ? Color.white.opacity(0.15) : Color.black.opacity(0.10)).frame(width: 15); VStack(alignment: .leading, spacing: 4) { Capsule().fill(key == "dark" ? Color.white.opacity(0.7) : Color.black.opacity(0.45)).frame(width: 28, height: 3); Capsule().fill(swatch(color)).frame(width: 39, height: 3); Capsule().fill(key == "dark" ? Color.white.opacity(0.16) : Color.black.opacity(0.12)).frame(width: 31, height: 3) }.padding(6); Spacer(minLength: 0) }.padding(6)
                    if key == "system" { Rectangle().fill(Color.black.opacity(0.75)).frame(width: 38).frame(maxWidth: .infinity, alignment: .trailing).clipShape(RoundedRectangle(cornerRadius: 7)) }
                }.frame(width: 76, height: 48).overlay(RoundedRectangle(cornerRadius: 8).stroke(mode == key ? accent : Color.primary.opacity(0.12), lineWidth: mode == key ? 2 : 1))
                Text(title).font(.system(size: 10)).foregroundStyle(mode == key ? accent : muted)
            }
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(mode == key ? .isSelected : [])
    }
}
