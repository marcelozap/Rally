import AVFoundation
import Foundation
import os

/// Sample-accurate, asset-free synthesizer for short game SFX.
///
/// ## Why this exists
///
/// Flappy Bird's "feel" depends on its SFX playing within a single video
/// frame of input. Achieving that with file-backed `AVAudioPlayerNode`s
/// means pre-loading buffers, pre-warming the engine, and praying the
/// scheduler co-operates. It's reliable but not _instant_.
///
/// `ToneSynth` sidesteps the buffer pipeline entirely. It uses
/// `AVAudioSourceNode` to generate samples on the audio I/O thread the
/// moment the engine asks for them. The latency from `play(_:)` to first
/// audible sample is bounded by the current audio buffer length (typically
/// 5–10 ms) and nothing else.
///
/// ## Architecture
///
/// * Fixed pool of `kVoiceCount` voices. No allocation on the hot path.
/// * Main thread writes activations into a lock-protected slot. The lock
///   (`OSAllocatedUnfairLock`) is held for ~nanoseconds.
/// * Render thread (audio I/O thread) iterates the pool and renders each
///   active voice into the output buffer, advancing phase + envelope
///   sample-by-sample.
/// * On voice exhaustion, oldest voice is stolen (a casual-game compromise
///   — at 8 voices and sub-second SFX, it's effectively never hit).
///
/// ## Thread-safety notes
///
/// `OSAllocatedUnfairLock` is held for a few nanoseconds at activation time
/// (copying a small struct into a slot) and for the duration of the render
/// block (one audio quantum, typically <1 ms of wall time). Main-thread
/// contention is therefore bounded by a single render quantum — a tradeoff
/// we accept for the brutally simple design.
final class ToneSynth {

    // MARK: - Public surface

    /// Oscillator waveform. Each has a distinct character — pick based on the
    /// SFX you're synthesizing:
    /// - `.sine` — pure, chime-like
    /// - `.triangle` — warm, woody, good for percussive bonks
    /// - `.square` — chip-tune, retro, video-game canonical
    /// - `.sawtooth` — buzzy, harsh, good for falls/dives
    enum Waveform: Sendable {
        case sine, square, triangle, sawtooth
    }

    /// A single SFX recipe. Build these once and re-fire them as many times
    /// as you want.
    struct Patch: Sendable {
        var freqStartHz: Double
        var freqEndHz: Double
        var durationMs: Double
        var waveform: Waveform
        var noiseMix: Float    // 0...1
        var peak: Float        // 0...1
        var attackMs: Double
        var releaseMs: Double
    }

    private(set) var sourceNode: AVAudioSourceNode!
    let outputFormat: AVAudioFormat

    // MARK: - Internals

    private struct Voice: Sendable {
        var active: Bool = false
        var phase: Double = 0
        var freqStartHz: Double = 0
        var freqEndHz: Double = 0
        var slideSamples: Int = 1
        var totalSamples: Int = 1
        var elapsedSamples: Int = 0
        var attackSamples: Int = 1
        var releaseSamples: Int = 1
        var peak: Float = 0
        var waveform: Waveform = .sine
        var noiseMix: Float = 0
        var rng: UInt64 = 0xDEAD_BEEF_CAFE_F00D
    }

    private static let kVoiceCount = 8
    private let sampleRate: Double
    private let voices: OSAllocatedUnfairLock<[Voice]>

    // MARK: - Init

    init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
        self.voices = OSAllocatedUnfairLock(initialState: Array(repeating: Voice(), count: Self.kVoiceCount))

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("ToneSynth: failed to construct AVAudioFormat")
        }
        self.outputFormat = format

        self.sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            return self.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
        }
    }

    // MARK: - Activation (main thread)

    func play(_ patch: Patch) {
        let voice = Voice(
            active: true,
            phase: 0,
            freqStartHz: patch.freqStartHz,
            freqEndHz: patch.freqEndHz,
            slideSamples: max(1, Int(patch.durationMs / 1000.0 * sampleRate)),
            totalSamples: max(1, Int(patch.durationMs / 1000.0 * sampleRate)),
            elapsedSamples: 0,
            attackSamples: max(1, Int(patch.attackMs / 1000.0 * sampleRate)),
            releaseSamples: max(1, Int(patch.releaseMs / 1000.0 * sampleRate)),
            peak: patch.peak,
            waveform: patch.waveform,
            noiseMix: max(0, min(1, patch.noiseMix)),
            rng: UInt64.random(in: 1...UInt64.max)
        )

        voices.withLockUnchecked { pool in
            if let free = pool.firstIndex(where: { !$0.active }) {
                pool[free] = voice
                return
            }
            // Steal the most-progressed voice — it has the least audible
            // remainder, so the interruption is the least noticeable.
            var stealIdx = 0
            var maxElapsed = -1
            for i in pool.indices where pool[i].elapsedSamples > maxElapsed {
                maxElapsed = pool[i].elapsedSamples
                stealIdx = i
            }
            pool[stealIdx] = voice
        }
    }

    // MARK: - Render (audio I/O thread)

    private func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

        // Zero the output buffer(s) up-front so we can additively mix.
        for buffer in abl {
            guard let base = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            base.update(repeating: 0, count: frameCount)
        }

        voices.withLockUnchecked { pool in
            for vIdx in pool.indices where pool[vIdx].active {
                renderVoice(voice: &pool[vIdx], into: abl, frameCount: frameCount)
            }
        }
        return noErr
    }

    private func renderVoice(
        voice: inout Voice,
        into abl: UnsafeMutableAudioBufferListPointer,
        frameCount: Int
    ) {
        for buffer in abl {
            guard let base = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for i in 0..<frameCount {
                if !voice.active { return }
                let sample = nextSample(&voice)
                base[i] += sample
                voice.elapsedSamples += 1
                if voice.elapsedSamples >= voice.totalSamples {
                    voice.active = false
                }
            }
        }
    }

    @inline(__always)
    private func nextSample(_ voice: inout Voice) -> Float {
        let slideT = Double(voice.elapsedSamples) / Double(voice.slideSamples)
        let freq = voice.freqStartHz + (voice.freqEndHz - voice.freqStartHz) * min(1.0, slideT)
        voice.phase += freq / sampleRate
        if voice.phase >= 1.0 { voice.phase -= 1.0 }

        let tone: Float
        switch voice.waveform {
        case .sine:
            tone = Float(sin(2 * .pi * voice.phase))
        case .square:
            tone = voice.phase < 0.5 ? 1.0 : -1.0
        case .triangle:
            tone = Float(4.0 * abs(voice.phase - 0.5) - 1.0)
        case .sawtooth:
            tone = Float(2.0 * voice.phase - 1.0)
        }

        let noise: Float
        if voice.noiseMix > 0 {
            // xorshift64 — fast, RT-safe, no allocations.
            var x = voice.rng
            x ^= x << 13
            x ^= x >> 7
            x ^= x << 17
            voice.rng = x
            noise = Float(Int32(truncatingIfNeeded: x)) / Float(Int32.max)
        } else {
            noise = 0
        }

        let mixed = tone * (1.0 - voice.noiseMix) + noise * voice.noiseMix

        let env: Float
        if voice.elapsedSamples < voice.attackSamples {
            env = Float(voice.elapsedSamples) / Float(voice.attackSamples)
        } else {
            let releaseStart = voice.totalSamples - voice.releaseSamples
            if voice.elapsedSamples >= releaseStart {
                let frac = Float(voice.elapsedSamples - releaseStart) / Float(voice.releaseSamples)
                env = max(0, 1.0 - frac)
            } else {
                env = 1.0
            }
        }

        return mixed * env * voice.peak
    }
}

// MARK: - Pre-built patches (the Flappy palette)

extension ToneSynth {

    /// Per-hit "point" chime. Quick rising sine.
    static var patchPoint: Patch {
        Patch(
            freqStartHz: Tunables.Audio.pointFreqHz,
            freqEndHz:   Tunables.Audio.pointGlideHz,
            durationMs:  Tunables.Audio.pointDurationMs,
            waveform:    Tunables.Audio.pointWaveform,
            noiseMix:    0,
            peak:        Tunables.Audio.peakLevel,
            attackMs:    Tunables.Audio.attackMs,
            releaseMs:   Tunables.Audio.releaseMs
        )
    }

    /// Perfect-hit thump. Triangle wave + noise for that Flappy bonk.
    static var patchHit: Patch {
        Patch(
            freqStartHz: Tunables.Audio.hitFreqHz,
            freqEndHz:   Tunables.Audio.hitGlideHz,
            durationMs:  Tunables.Audio.hitDurationMs,
            waveform:    Tunables.Audio.hitWaveform,
            noiseMix:    Tunables.Audio.hitNoiseMix,
            peak:        Tunables.Audio.peakLevel,
            attackMs:    Tunables.Audio.attackMs,
            releaseMs:   Tunables.Audio.releaseMs
        )
    }

    /// Soft swipe whoosh. Mostly noise.
    static var patchWing: Patch {
        Patch(
            freqStartHz: Tunables.Audio.wingFreqHz,
            freqEndHz:   Tunables.Audio.wingGlideHz,
            durationMs:  Tunables.Audio.wingDurationMs,
            waveform:    Tunables.Audio.wingWaveform,
            noiseMix:    Tunables.Audio.wingNoiseMix,
            peak:        Tunables.Audio.peakLevel * 0.7,
            attackMs:    2,
            releaseMs:   Tunables.Audio.releaseMs
        )
    }

    /// Combo-break "death" — the falling wail.
    static var patchDie: Patch {
        Patch(
            freqStartHz: Tunables.Audio.dieFreqHz,
            freqEndHz:   Tunables.Audio.dieGlideHz,
            durationMs:  Tunables.Audio.dieDurationMs,
            waveform:    Tunables.Audio.dieWaveform,
            noiseMix:    Tunables.Audio.dieNoiseMix,
            peak:        Tunables.Audio.peakLevel,
            attackMs:    Tunables.Audio.attackMs,
            releaseMs:   140
        )
    }

    /// Combo-tier stinger. Frequency steps up per tier.
    static func patchTier(_ tier: Int) -> Patch {
        let bumped = Tunables.Audio.tierBaseFreqHz + Tunables.Audio.tierStepHz * Double(max(0, tier - 1))
        return Patch(
            freqStartHz: bumped,
            freqEndHz:   bumped * 1.5,
            durationMs:  Tunables.Audio.tierDurationMs,
            waveform:    Tunables.Audio.tierWaveform,
            noiseMix:    0,
            peak:        Tunables.Audio.peakLevel * 0.9,
            attackMs:    Tunables.Audio.attackMs,
            releaseMs:   80
        )
    }
}
