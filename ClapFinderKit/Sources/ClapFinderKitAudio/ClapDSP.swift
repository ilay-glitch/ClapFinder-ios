import Accelerate
import AVFoundation

// MARK: - ClapDSP

/// Small, nonisolated DSP helpers over an `AVAudioPCMBuffer`'s channel-0
/// float samples. Pure measurement — no state, no actor isolation — so the
/// audio-thread tap can call them directly and tests can exercise them in
/// isolation.
enum ClapDSP {

    /// Root-mean-square amplitude of channel 0. Uses `vDSP_measqv` (mean
    /// square) so only one `sqrt` is needed. `0` for an empty/non-float buffer.
    nonisolated static func rmsAmplitude(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        var meanSquare: Float = 0
        vDSP_measqv(data[0], 1, &meanSquare, vDSP_Length(buffer.frameLength))
        return sqrt(meanSquare)
    }

    /// Peak absolute amplitude of channel 0. `0` for an empty/non-float buffer.
    nonisolated static func peakAmplitude(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        var peak: Float = 0
        vDSP_maxmgv(data[0], 1, &peak, vDSP_Length(buffer.frameLength))
        return peak
    }
}
