import Foundation

// MARK: - ResponseSuppression

/// Feedback-loop guard: ignores detector triggers while the response sound is
/// playing and for a tail grace afterwards.
///
/// Device evidence (2026-06-22 session): the played alert's transients pass the
/// crest gate and its decaying echo re-triggered detection at −54.1 dBFS — the
/// phone barked at itself every cooldown. Response-side fix; the detector is
/// untouched. Pure logic → CLI-testable.
///
/// Rules:
/// - While the player reports `isPlaying`, every trigger is suppressed **and**
///   extends the tail (so the grace always covers the end of audible playback).
/// - After playback, triggers are suppressed until the tail expires — this is
///   what catches the echo tail (the −54 dBFS accept), not just the playback.
/// - `responseStarted` seeds the tail at fire time, covering instant/failed
///   playback where `isPlaying` never goes true.
struct ResponseSuppression {

    /// Grace after the last audible-playback moment. 1.0 s: the observed echo
    /// re-trigger landed ~0.2 s after the alert's transients; 1.0 s is airtight
    /// without swallowing a genuine follow-up clap much beyond the detector's
    /// own 1.0 s cooldown.
    let tailGrace: TimeInterval

    private(set) var suppressedUntil: Date = .distantPast

    init(tailGrace: TimeInterval = 1.0) {
        self.tailGrace = tailGrace
    }

    /// `true` ⇒ ignore this trigger. Call for every detector fire.
    mutating func shouldSuppress(isPlaying: Bool, now: Date) -> Bool {
        if isPlaying {
            suppressedUntil = now.addingTimeInterval(tailGrace)
            return true
        }
        return now < suppressedUntil
    }

    /// Call when a response fires (sound starts): seeds the tail.
    mutating func responseStarted(now: Date) {
        suppressedUntil = now.addingTimeInterval(tailGrace)
    }
}
