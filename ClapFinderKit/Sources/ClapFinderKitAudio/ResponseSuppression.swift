import Foundation

// MARK: - ResponseSuppression

/// Feedback-loop guard: ignores detector triggers while the response sound is
/// playing and for a tail grace after playback **ends**.
///
/// Device evidence (2026-06-22, two sessions): the played alert's echo re-paired
/// the double-clap FSM 1.3–2.5 s after each bark, at −45…−55 dBFS, chaining
/// barks indefinitely. A first fix that extended the tail from *observed
/// triggers* failed live: the detector's own 1.0 s cooldown means no triggers
/// ever arrive during playback, so an observation-based tail never extends —
/// the echo lands after both cooldown and tail and re-fires. The grace must be
/// anchored to the **authoritative playback end**
/// (`SoundPlayer.lastPlaybackEndedAt`), which trigger timing cannot miss.
///
/// Rules (any one suppresses):
/// 1. `isPlaying` — the response sound is audible right now.
/// 2. `now < playbackEndedAt + tailGrace` — the echo tail after playback.
/// 3. `now < responseStarted + tailGrace` — seed covering failed/instant
///    playback where `isPlaying` never goes true.
///
/// Response-side only; the detector is untouched. Pure logic → CLI-testable.
struct ResponseSuppression {

    /// Grace after playback ends. Device data: echo re-triggers arrived up to
    /// ~1 s after the bark's end (ACCEPT chains at 1.3–2.5 s from bark *start*,
    /// bark ~1–2 s long). 1.5 s covers the observed tail with margin.
    let tailGrace: TimeInterval

    private(set) var seededUntil: Date = .distantPast

    init(tailGrace: TimeInterval = 1.5) {
        self.tailGrace = tailGrace
    }

    /// `true` ⇒ ignore this trigger. Call for every detector fire.
    /// - Parameter playbackEndedAt: `SoundPlayer.lastPlaybackEndedAt` — the
    ///   authoritative end of the last audible response.
    func shouldSuppress(isPlaying: Bool, playbackEndedAt: Date?, now: Date) -> Bool {
        if isPlaying { return true }
        if let ended = playbackEndedAt, now < ended.addingTimeInterval(tailGrace) { return true }
        return now < seededUntil
    }

    /// Call when a response fires: seeds a grace so failed/instant playback
    /// (where `isPlaying` never goes true) is still covered.
    mutating func responseStarted(now: Date) {
        seededUntil = now.addingTimeInterval(tailGrace)
    }
}
