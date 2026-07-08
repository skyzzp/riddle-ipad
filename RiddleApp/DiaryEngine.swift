import UIKit
import PencilKit
import RiddleKit

/// Owns a single conversational turn end to end. Replaces the informal
/// `Coordinator.runTurn` closure. Every visible effect and its on-device-tuned
/// timing is lifted VERBATIM from Phase 1 — only the owner and the explicit
/// `DiaryState` transitions are new. Stages 7/9 extend this class.
@MainActor
final class DiaryEngine {
    private(set) var state: DiaryState = .listening
    private unowned let container: PageContainerView
    private let ink: InkController

    private var turnTask: Task<Void, Never>?
    private var lingerDismiss: LingerDismiss?
    private let memory: Memory
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundedAt: Date?

    init(container: PageContainerView, ink: InkController, memory: Memory) {
        self.container = container
        self.ink = ink
        self.memory = memory
    }

    /// Validated state change — an illegal edge trips a precondition in debug.
    private func transition(to next: DiaryState) {
        precondition(state.canTransition(to: next), "illegal DiaryState \(state)→\(next)")
        state = next
    }

    // MARK: Background assertion

    /// Keep the turn's Task alive ~30s if the app is backgrounded mid-turn, so a
    /// brief background completes the turn instead of stranding it.
    private func beginAssertion() {
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "riddle-turn") { [weak self] in
            self?.endAssertion()
        }
    }
    private func endAssertion() {
        if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
    }

    /// Brief backgrounds need no action: the assertion kept the Task alive, so the
    /// turn either finished (it snaps/lingers on its own) or is still streaming (it
    /// resumes). Cold-launch recovery is the only explicit path (resumeIfPending).
    func didEnterBackground() { backgroundedAt = Date() }
    func willEnterForeground() { backgroundedAt = nil }

    /// Kicks off a turn from the current page (wired to `InkController.onCommit`).
    func beginTurn() {
        let v = container
        let scale = UIScreen.main.scale
        guard state == .listening,
              let png = PageSnapshotter.snapshotPNG(v.canvas.drawing,
                          canvasSize: v.canvas.bounds.size, scale: scale) else {
            v.canvas.drawing = PKDrawing()
            ink.reset()
            return
        }
        let imageB64 = png.base64EncodedString()
        let turnStamp = Date()
        ink.isListening = false
        v.canvas.isUserInteractionEnabled = false
        beginAssertion()
        // Persist the turn at drink-time so a hard kill mid-turn is recoverable.
        PendingStore.save(PendingTurn(snapshotBase64: imageB64, timestamp: turnStamp, reply: nil))
        transition(to: .drinking)

        // Compose her ink over the REAL aged page, overlay it opaquely, then
        // clear the live canvas beneath (hidden by the overlay → no flicker).
        let inkOnCream = UIGraphicsImageRenderer(bounds: v.canvas.bounds).image { ctx in
            if let surf = v.pageSurface { surf.draw(in: v.canvas.bounds) }
            else { PageContainerView.agedBaseUI.setFill(); ctx.fill(v.canvas.bounds) }
            let light = UITraitCollection(userInterfaceStyle: .light)
            var inkImg = UIImage()
            light.performAsCurrent {
                inkImg = v.canvas.drawing.image(from: v.canvas.bounds, scale: scale)
            }
            inkImg.draw(in: v.canvas.bounds)
        }
        let drink = DissolveView(frame: v.dissolveHost.bounds)
        drink.pageColor = PageContainerView.agedBaseUI
        v.dissolveHost.addSubview(drink)
        v.canvas.drawing = PKDrawing()

        // Start the reply stream now — network runs during the drink.
        let cfg = OracleConfig(baseURL: AppConfig.baseURL, apiKey: AppConfig.apiKey,
                               model: AppConfig.replyModel)
        let client = OracleClient(config: cfg)
        let stream = client.ask(imageBase64: imageB64, store: memory.store)
        v.overlayHost.sublayers?.forEach { $0.removeFromSuperlayer() }

        turnTask = Task { @MainActor in
            // Buffer the whole reply WHILE the page drinks (2.2s hides the latency),
            // capturing the stream error so a timeout can fade quietly (Task 9.6).
            let collector = Task { () -> (sentences: [String], error: Error?) in
                var out: [String] = []
                do { for try await s in stream { out.append(s) }; return (out, nil) }
                catch { return (out, error) }
            }
            // DRINK
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                drink.dissolve(image: inkOnCream, duration: 2.2) {
                    drink.removeFromSuperview(); c.resume()
                }
            }
            // THINKING — reply not yet buffered → the pulse lives here (Task 6.3).
            transition(to: .thinking)
            let pulse = ThinkingPulse(on: v.overlayHost)
            pulse.start()
            let (collected, streamError) = await collector.value
            pulse.stop()

            var sentences = collected
            if sentences.isEmpty {
                // A bare timeout fades quietly; every other failure blurs in Tom's voice.
                guard let line = inCharacterError(for: streamError) else {
                    transition(to: .listening)
                    PendingStore.clear()
                    v.canvas.isUserInteractionEnabled = true
                    self.ink.reset(); self.ink.isListening = true
                    self.endAssertion()
                    return
                }
                sentences = [line]
            }

            // Commit this turn to memory now (herText backfills when the side-call lands).
            let reply = sentences.joined(separator: " ")
            self.memory.commit(turn: Turn(herText: nil, tomReply: reply, timestamp: turnStamp))
            // Persist the buffered reply so a kill mid-write can snap it on relaunch.
            PendingStore.save(PendingTurn(snapshotBase64: imageB64, timestamp: turnStamp, reply: sentences))
            // Fire-and-forget side-call: transcribe + extract, off the hot path.
            let sideCfg = OracleConfig(baseURL: AppConfig.baseURL, apiKey: AppConfig.apiKey,
                                       model: AppConfig.sideModel)
            let known = self.memory.store.notes
            Task.detached {
                let (transcription, notes) = await OracleClient(config: sideCfg)
                    .transcribeAndExtract(imageBase64: imageB64, currentNotes: known)
                await MainActor.run {
                    if let t = transcription { self.memory.setHerText(t, forTurnAt: turnStamp) }
                    if !notes.isEmpty { self.memory.applyNotes(notes) }
                }
                // Compaction (rare): merge/dedup when the notes list grows past the threshold.
                let due = await MainActor.run { self.memory.needsCompaction }
                if due {
                    let all = await MainActor.run { self.memory.store.notes }
                    if let merged = await OracleClient(config: sideCfg).compactNotes(all) {
                        await MainActor.run { self.memory.replaceNotes(merged) }
                    }
                }
            }

            await self.presentAndFinish(sentences, animated: true)
        }
    }

    /// Write `sentences` (animated or snapped), linger until dismissed, fade, and
    /// return to Listening. Clears the pending record + ends the assertion. Shared
    /// by a live turn and cold-launch recovery. Markdown is stripped here so it
    /// never reaches the quill.
    private func presentAndFinish(_ sentences: [String], animated: Bool) async {
        let v = container
        transition(to: .replying)
        let clean = sentences.map { stripMarkdown($0) }
        let basePx = v.overlayHost.bounds.width * (96.0 / 1872.0)
        let fit = fitReply(sentences: clean, baseFontPx: 96, basePx: basePx,
                           pageWidth: v.overlayHost.bounds.width,
                           pageHeight: v.overlayHost.bounds.height)
        let writer = QuillWriter(host: v.overlayHost, font: fit.font,
                                 pageSize: v.overlayHost.bounds.size, px: fit.px, yStart: fit.yStart)
        for (i, sentence) in clean.enumerated() {
            if animated && i > 0 {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 160_000_000...340_000_000))
            }
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                writer.write(sentence: sentence, animated: animated) { c.resume() }
            }
        }
        transition(to: .lingering)
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            self.lingerDismiss = LingerDismiss(on: v, timeout: 120) { c.resume() }
        }
        self.lingerDismiss = nil
        transition(to: .fadingReply)
        let replyOnCream = UIGraphicsImageRenderer(bounds: v.overlayHost.bounds).image { ctx in
            if let surf = v.pageSurface { surf.draw(in: v.overlayHost.bounds) }
            else { PageContainerView.agedBaseUI.setFill(); ctx.fill(v.overlayHost.bounds) }
            v.overlayHost.render(in: ctx.cgContext)
        }
        let fade = DissolveView(frame: v.dissolveHost.bounds)
        fade.pageColor = PageContainerView.agedBaseUI
        v.dissolveHost.addSubview(fade)
        writer.clear()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            fade.dissolve(image: replyOnCream, duration: 1.3) { fade.removeFromSuperview(); c.resume() }
        }
        transition(to: .listening)
        PendingStore.clear()
        v.canvas.isUserInteractionEnabled = true
        self.ink.reset()
        self.ink.isListening = true
        self.endAssertion()
    }

    /// Called once on launch after the container has bounds. Recovers a turn
    /// interrupted by a hard kill (snap a buffered reply / re-issue an unanswered
    /// one / write an in-character blur if it's too stale).
    func resumeIfPending() {
        guard state == .listening, let pending = PendingStore.load() else { return }
        // The container needs real bounds for fitReply/rendering; on a cold launch
        // it may still be zero on the first runloop — retry until it's laid out.
        guard container.overlayHost.bounds.width > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.resumeIfPending() }
            return
        }
        let age = Date().timeIntervalSince(pending.timestamp)
        let action = recoveryAction(hasPending: true,
                                    replyBuffered: (pending.reply?.isEmpty == false),
                                    ageSeconds: age)
        let v = container
        ink.isListening = false
        v.canvas.isUserInteractionEnabled = false
        beginAssertion()
        turnTask = Task { @MainActor in
            switch action {
            case .snap:
                await self.presentAndFinish(pending.reply ?? [], animated: false)
            case .blur:
                await self.presentAndFinish(["the ink blurred, and would not settle. Write to me again."],
                                            animated: true)
            case .reissue:
                self.transition(to: .thinking)
                let pulse = ThinkingPulse(on: v.overlayHost); pulse.start()
                let cfg = OracleConfig(baseURL: AppConfig.baseURL, apiKey: AppConfig.apiKey,
                                       model: AppConfig.replyModel)
                var out: [String] = []
                do { for try await s in OracleClient(config: cfg)
                        .ask(imageBase64: pending.snapshotBase64, store: self.memory.store) { out.append(s) }
                } catch {}
                pulse.stop()
                if out.isEmpty { out = ["the ink blurred and would not settle…"] }
                self.memory.commit(turn: Turn(herText: nil, tomReply: out.joined(separator: " "),
                                              timestamp: pending.timestamp))
                await self.presentAndFinish(out, animated: true)
            case .none:
                self.endAssertion()
                v.canvas.isUserInteractionEnabled = true
                self.ink.reset(); self.ink.isListening = true
            }
        }
    }
}

/// A weak handle to the engine so `ContentView` can forward scene-phase changes
/// without owning the UIKit view. Set in `PageView.makeUIView`.
@MainActor
final class EngineBox {
    weak var engine: DiaryEngine?
}
