import Foundation
import Testing

@testable import PiliPlus

@Suite("WebDAV")
struct WebDAVTests {
    private let payloadJSON = """
    {
      "version": 1,
      "exportedAt": "2026-01-01T00:00:00Z",
      "history": [
        {
          "bvid": "BV1xx411c7mD",
          "aid": 100,
          "cid": 200,
          "title": "备份视频",
          "coverURLString": "https://example.com/cover.jpg",
          "ownerName": "UP",
          "duration": 600,
          "position": 120,
          "pageIndex": 0,
          "pageTitle": "P1",
          "updatedAt": "2026-01-02T03:04:05Z"
        }
      ],
      "settings": {
        "defaultQuality": 80,
        "codecPreference": "hevc",
        "backgroundPlaybackEnabled": true,
        "pictureInPictureEnabled": true,
        "resumePlaybackEnabled": true,
        "sponsorBlockEnabled": true,
        "audioOnlyEnabled": false,
        "danmakuEnabled": true,
        "danmakuFontScale": 1.1,
        "danmakuOpacity": 0.8,
        "danmakuSpeed": 1.2,
        "danmakuArea": 0.6,
        "audioNormalizationMode": "bewly",
        "loudnessTargetLUFS": -20,
        "loudnessStrength": 80,
        "appearance": "dark"
      }
    }
    """

    private func decodePayload() throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: Data(payloadJSON.utf8))
    }

    @Test("备份 JSON 解码与历史映射")
    func decodesBackup() throws {
        let payload = try decodePayload()
        #expect(payload.version == 1)
        #expect(payload.history.count == 1)

        let record = payload.history[0].makeRecord()
        #expect(record.bvid == "BV1xx411c7mD")
        #expect(record.position == 120)
        #expect(record.pageTitle == "P1")
        #expect(record.videoKey == "BV1xx411c7mD")
    }

    @Test("设置备份应用到 SettingsStore")
    @MainActor
    func appliesSettings() throws {
        let suiteName = "webdav.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(defaults: defaults)

        try decodePayload().settings.apply(to: settings)

        #expect(settings.defaultQuality == 80)
        #expect(settings.codecPreference == .hevc)
        #expect(settings.danmakuFontScale == 1.1)
        #expect(settings.audioNormalizationMode == "bewly")
        #expect(settings.loudnessTargetLUFS == -20)
        #expect(settings.appearance == .dark)
        #expect(settings.sponsorBlockEnabled)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("备份编码后仍可解码")
    func encodesRoundTrip() throws {
        let payload = try decodePayload()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupPayload.self, from: data)
        #expect(decoded.history.count == payload.history.count)
        #expect(decoded.settings.audioNormalizationMode == "bewly")
        #expect(decoded.exportedAt == payload.exportedAt)
    }
}
