import Foundation

// MARK: - ClapDetector diagnostics emit + test hook
//
// Split out of ClapDetector.swift so the measure-first instrumentation
// (CLAP_DIAGNOSTICS.md) carries its own weight. The stored `diagnostics`
// session lives on the type; this is just the emit helper the FSM calls and
// the test observation hook. None of it touches the decision path.

extension ClapDetector {

    /// Emits one diagnostic row for the gate the FSM just took. DEBUG-only work;
    /// compiles to an empty call in Release. Reads the same values the gate did —
    /// it never influences the decision.
#if DEBUG
    func diag(_ gate: ClapDiagnostics.Gate, _ dBFS: Float, _ crest: Float,
              hfr: Float, sfm: Float, dtMs: Double = -1) {
        diagnostics.emit(gate, dBFS: dBFS, crest: crest, hfr: hfr, sfm: sfm, dtMs: dtMs)
    }

    /// Test hook — observes each emitted diagnostic candidate.
    @_spi(Testing)
    public var onDiagnostic: ((ClapDiagnostics.Candidate) -> Void)? {
        get { diagnostics.onEmit }
        set { diagnostics.onEmit = newValue }
    }
#else
    @inline(__always)
    func diag(_ gate: ClapDiagnostics.Gate, _ dBFS: Float, _ crest: Float,
              hfr: Float, sfm: Float, dtMs: Double = -1) {}
#endif
}
