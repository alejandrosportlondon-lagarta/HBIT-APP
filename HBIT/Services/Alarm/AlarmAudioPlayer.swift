import AVFoundation
import Foundation

/// Looping, volume-ramping alarm tone (ADR 002: audio keep-alive while the
/// app is frontmost). The tone is synthesized at runtime — a 16-bit WAV of
/// an 880 Hz beep — so there is no binary asset to manage. The `.playback`
/// session category means it plays regardless of the silent switch once the
/// app is open.
@MainActor
final class AlarmAudioPlayer {
    private var player: AVAudioPlayer?

    var isPlaying: Bool { player?.isPlaying ?? false }

    func start(rampDuration: TimeInterval = 30) {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)

            let newPlayer = try AVAudioPlayer(data: Self.beepWAV)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0.05
            newPlayer.play()
            newPlayer.setVolume(1.0, fadeDuration: rampDuration)
            player = newPlayer
        } catch {
            // Losing audio must never block dismissal — the notification
            // chain is still ringing. Report and carry on.
            Telemetry.capture(error: error, context: ["phase": "alarm_audio_start"])
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// One second of 44.1 kHz mono 16-bit PCM: a 0.4 s 880 Hz beep with
    /// 10 ms fades, then silence. Looped forever by the player.
    static let beepWAV: Data = {
        let sampleRate = 44_100
        let totalSamples = sampleRate
        let toneSamples = Int(0.4 * Double(sampleRate))
        let fadeSamples = sampleRate / 100

        var samples = [Int16](repeating: 0, count: totalSamples)
        for i in 0..<toneSamples {
            let time = Double(i) / Double(sampleRate)
            var amplitude = sin(2 * .pi * 880 * time)
            if i < fadeSamples {
                amplitude *= Double(i) / Double(fadeSamples)
            } else if i > toneSamples - fadeSamples {
                amplitude *= Double(toneSamples - i) / Double(fadeSamples)
            }
            samples[i] = Int16(amplitude * 0.8 * Double(Int16.max))
        }

        var data = Data()
        func appendASCII(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        let dataSize = UInt32(totalSamples * 2)
        appendASCII("RIFF")
        append32(36 + dataSize)
        appendASCII("WAVE")
        appendASCII("fmt ")
        append32(16)
        append16(1) // PCM
        append16(1) // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2)) // byte rate
        append16(2) // block align
        append16(16) // bits per sample
        appendASCII("data")
        append32(dataSize)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }()
}
