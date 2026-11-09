import XCTest
@testable import MacMonitor

final class FeatureTests: XCTestCase {
    func testLanguageAndAppearancePreferencesResolve() {
        XCTAssertEqual(AppLanguage.resolve("en"), "en")
        XCTAssertEqual(AppLanguage.resolve("zh-Hans"), "zh-Hans")
        XCTAssertEqual(translate("设置", language: "en"), "Settings")
        XCTAssertEqual(translate("设置", language: "zh-Hans"), "设置")
        XCTAssertNil(selectedColorScheme("system"))
        XCTAssertEqual(selectedColorScheme("light"), .light)
        XCTAssertEqual(selectedColorScheme("dark"), .dark)
    }
    func testLsofParserSeparatesProcessesAndFileRecords() {
        let data = Data("p42\0cweb\0\nf5\0PTCP\0n127.0.0.1:3000\0TST=LISTEN\0\nf6\0PUDP\0n*:5353\0\np7\0cother\0\nf3\0n/tmp/a file\0\n".utf8)
        let rows = parseLsof(data)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].pid, "42")
        XCTAssertEqual(rows[0].state, "LISTEN")
        XCTAssertEqual(rows[1].proto, "UDP")
        XCTAssertEqual(rows[2].command, "other")
        XCTAssertEqual(rows[2].name, "/tmp/a file")
    }
    func testHistoryThrottlesAndPurgesOldSamples() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pulse-\(UUID()).sqlite3")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(atPath: url.path + "-wal"); try? FileManager.default.removeItem(atPath: url.path + "-shm") }
        let store = HistoryStore(databaseURL: url)
        XCTAssertNil(store.error)
        var snapshot = Snapshot()
        snapshot.sampledAt = Date().addingTimeInterval(-8 * 86400)
        snapshot.cpu = 25
        store.save(snapshot)
        snapshot.sampledAt = Date().addingTimeInterval(-120)
        snapshot.cpu = 42
        store.save(snapshot)
        snapshot.sampledAt = Date().addingTimeInterval(-90)
        snapshot.cpu = 99
        store.save(snapshot)
        let rows = store.load(hours: 24 * 9)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.cpu, 42)
        XCTAssertNil(store.error)
        store.clear()
        XCTAssertTrue(store.load(hours: 24).isEmpty)
        XCTAssertNil(store.error)
    }
}

extension FeatureTests {
    func testPreferenceMigrationPreservesExistingValuesAndRunsOnce() throws {
        let suite = "MacFalconTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: "appearanceMode")
        SettingsMigration.migrate(defaults: defaults, legacy: ["interval": 5.0, "appearanceMode": "light"])
        XCTAssertEqual(defaults.double(forKey: "interval"), 5)
        XCTAssertEqual(defaults.string(forKey: "appearanceMode"), "dark")
        SettingsMigration.migrate(defaults: defaults, legacy: ["interval": 10.0])
        XCTAssertEqual(defaults.double(forKey: "interval"), 5)
    }
    func testHistoryMigrationCopiesAndKeepsOriginal() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("macfalcon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = folder.appendingPathComponent("old.sqlite3"), new = folder.appendingPathComponent("new.sqlite3")
        let store = HistoryStore(databaseURL: old)
        var sample = Snapshot(); sample.sampledAt = Date().addingTimeInterval(-120); sample.cpu = 37
        store.save(sample)
        try HistoryStore.migrateDatabase(from: old, to: new)
        XCTAssertEqual(HistoryStore(databaseURL: new).load(hours: 1).first?.cpu, 37)
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.path))
    }
}
