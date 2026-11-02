import Testing

@testable import PiliPlus

@Suite("AudioNormalization")
struct AudioNormalizationTests {
    @Test("无服务端响度数据时只挂 dynaudnorm + alimiter")
    func filterGraphWithoutMeasurement() {
        let graph = AudioNormalization.bewlyFilterGraph(
            targetLUFS: -18,
            strength: 75,
            measurement: nil
        )
        #expect(
            graph == "dynaudnorm=f=200:g=7:p=0.89125:m=2.99:r=0.0964:n=1:b=1:t=0.0024,"
                + "alimiter=limit=0.89125:attack=5:release=80:level=0:latency=1"
        )
    }

    @Test("有服务端响度数据时前置 volume 预增益")
    func filterGraphWithMeasurement() {
        let graph = AudioNormalization.bewlyFilterGraph(
            targetLUFS: -18,
            strength: 100,
            measurement: LoudnessMeasurement(integratedLUFS: -22.5)
        )
        #expect(
            graph == "volume=4.50dB,"
                + "dynaudnorm=f=200:g=5:p=0.89125:m=2.82:r=0.0964:n=1:b=1:t=0.0024,"
                + "alimiter=limit=0.89125:attack=5:release=80:level=0:latency=1"
        )
    }

    @Test("目标响度、强度与预增益均被限制在安全区间")
    func clampsUnsafeValues() {
        #expect(AudioNormalization.clampTarget(-100) == -24)
        #expect(AudioNormalization.clampTarget(0) == -14)
        #expect(AudioNormalization.clampStrength(10) == 40)
        #expect(AudioNormalization.clampStrength(999) == 100)

        let gain = AudioNormalization.baseGainDB(
            targetLUFS: -14,
            strength: 100,
            measurement: LoudnessMeasurement(integratedLUFS: -60)
        )
        #expect(gain == 9)
    }

    @Test("无效响度测量被忽略")
    func ignoresInvalidMeasurement() {
        #expect(!LoudnessMeasurement(integratedLUFS: -80).isValid)
        #expect(!LoudnessMeasurement(integratedLUFS: 0).isValid)
        #expect(LoudnessMeasurement(integratedLUFS: -18.6).isValid)

        let graph = AudioNormalization.bewlyFilterGraph(
            targetLUFS: -18,
            strength: 75,
            measurement: LoudnessMeasurement(integratedLUFS: -80)
        )
        #expect(!graph.hasPrefix("volume="))
    }

    @Test("mpv af 参数包装与禁用逻辑")
    func mpvArgument() {
        let bewly = AudioNormalization.mpvAudioFilter(rawCode: "bewly", measurement: nil)
        #expect(bewly.hasPrefix("lavfi=[dynaudnorm="))
        #expect(bewly.hasSuffix("]"))

        #expect(AudioNormalization.mpvAudioFilter(rawCode: "0").isEmpty)
        #expect(AudioNormalization.mpvAudioFilter(rawCode: "3").isEmpty)
        #expect(AudioNormalization.mpvAudioFilter(rawCode: "1") == "lavfi=[dynaudnorm=g=5:f=250:r=0.9:p=0.5]")
        #expect(AudioNormalization.mpvAudioFilter(rawCode: "2") == "lavfi=[loudnorm=I=-16:LRA=11:TP=-1.5]")
    }

    @Test("摘要文案覆盖三种状态")
    func summaryText() {
        let disabled = AudioNormalization.summary(rawCode: "0")
        #expect(!disabled.isEnabled)
        #expect(disabled.statusText == "已关闭")

        let pending = AudioNormalization.summary(rawCode: "bewly", measurement: nil)
        #expect(pending.statusText == "实时局部动态均衡生效中（目标 -18 LUFS）")

        let measured = AudioNormalization.summary(
            rawCode: "bewly",
            targetLUFS: -18,
            strength: 100,
            measurement: LoudnessMeasurement(integratedLUFS: -22.5)
        )
        #expect(measured.statusText == "原始 -22.5 LUFS · 预增益 +4.5 dB")
    }
}
