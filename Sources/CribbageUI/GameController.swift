import CribbageCore
import SwiftUI

@MainActor
public final class GameController: ObservableObject {
    private enum Job: CaseIterable {
        case dealCut, deal, cut, opponent, hold, count, collect, toast, demo
    }

    private struct ShowingCache {
        let stage: Stage
        let isHoldingTable: Bool
        let isCollecting: Bool
        let showing: Showing?
    }

    @Published public private(set) var game: Game {
        didSet { stageMayHaveChanged(from: oldValue) }
    }
    @Published private(set) var dealtCount = 12
    @Published private(set) var cutStep = CutStep.done
    @Published private(set) var selected: [Int] = []
    @Published private(set) var toast: TableToast?
    @Published private(set) var pulses: Set<Pulse> = []
    @Published private(set) var shakes: [Card: Int] = [:]
    @Published private(set) var hoveredCard: Card?
    @Published private(set) var isHoldingTable = false
    @Published private(set) var isCollecting = false
    @Published private(set) var heldScores: [Player: Int]?
    @Published private(set) var shownCount = 0
    @Published private(set) var countRevealed = 0
    @Published private(set) var isCountFinished = true
    @Published private(set) var celebrationStart = Date.distantPast
    @Published private(set) var dealCutStep = DealCutStep.done
    @Published private(set) var displayRound = 0
    @Published private(set) var goTag: GoTag?
    @Published private(set) var isBoardShown = false
    @Published private(set) var showsWinner = false

    private var gameNumber = 0
    private var lastStage: Stage?
    private var seenEvents = 0
    private var isStartingGame = false
    private var showingCache: ShowingCache?
    private var jobs: [Job: Task<Void, Never>] = [:]
    private var delayed: [Int: Task<Void, Never>] = [:]
    private var nextDelayedID = 0

    public init() {
        game = Game()
    }

    var stage: Stage {
        Stage(gameNumber: gameNumber, handNumber: game.handNumber, phase: game.phase)
    }

    var showing: Showing? {
        if let cache = showingCache, cache.stage == stage, cache.isHoldingTable == isHoldingTable, cache.isCollecting == isCollecting {
            return cache.showing
        }
        let showing = isHoldingTable || isCollecting ? nil : game.showing ?? game.winningShowing
        showingCache = ShowingCache(stage: stage, isHoldingTable: isHoldingTable, isCollecting: isCollecting, showing: showing)
        return showing
    }

    public func toggleBoard() {
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) { isBoardShown.toggle() }
    }

    public func newGame(seed: UInt64 = .random(in: .min ... .max)) {
        cancelGameTasks()
        gameNumber += 1
        isStartingGame = true
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
            dealCutStep = .centered
            isHoldingTable = false
            isCollecting = false
            showsWinner = false
            game = Game(seed: seed)
            selected = []
            toast = nil
            heldScores = nil
            shownCount = 0
            countRevealed = 0
            isCountFinished = true
            cutStep = .done
            hoveredCard = nil
            shakes = [:]
            pulses = []
        }
        isStartingGame = false
        seenEvents = 0
        runDealCut()
    }

    public func runDemo(seed: UInt64) {
        newGame(seed: seed)
        run(.demo) { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_100))
                switch self.game.phase {
                case .discard:
                    guard self.dealtCount == 12, self.myCards.count == Game.dealtHandSize else { continue }
                    self.hover(self.myCards[1], isInside: true)
                    self.pressNumber(2)
                    try? await Task.sleep(for: .milliseconds(450))
                    self.hover(self.myCards[1], isInside: false)
                    self.pressNumber(5)
                    try? await Task.sleep(for: .milliseconds(700))
                    self.pressEnter()
                case .play:
                    guard self.game.turn == .me, !self.isHoldingTable,
                          let card = Opponent.choosePlay(hand: self.myCards, sequence: self.game.sequence, count: self.game.count),
                          let index = self.myCards.firstIndex(of: card) else { continue }
                    self.pressNumber(index + 1)
                case .show:
                    guard self.isCountFinished, !self.isCollecting else { continue }
                    try? await Task.sleep(for: .milliseconds(1_200))
                    self.pressEnter()
                case .gameOver:
                    return
                }
            }
        }
    }

    public func pressNumber(_ number: Int) {
        if isBoardShown {
            toggleBoard()
            return
        }
        let index = number - 1
        switch game.phase {
        case .discard:
            guard dealtCount == 12, myCards.count == Game.dealtHandSize, myCards.indices.contains(index) else { return }
            withAnimation(.spring(duration: 0.3, bounce: 0.45)) {
                if let position = selected.firstIndex(of: index) {
                    selected.remove(at: position)
                } else {
                    selected.append(index)
                    if selected.count > 2 { selected.removeFirst() }
                }
            }
        case .play:
            guard game.turn == .me, !isHoldingTable, cutStep == .done, myCards.indices.contains(index) else { return }
            let card = myCards[index]
            finishPendingReset()
            let before = game.scores
            let landing = game.count + card.value
            let played = withAnimation(.spring(duration: 0.5, bounce: 0.22)) { game.play(card, by: .me) }
            guard played else {
                showToast("over 31", color: .orange)
                withAnimation(.linear(duration: 0.4)) { shakes[card, default: 0] += 1 }
                return
            }
            hoveredCard = nil
            landCard(scoresBefore: before, landing: landing)
            driveOpponent()
        case .show, .gameOver:
            break
        }
    }

    public func pressEnter() {
        if isBoardShown {
            toggleBoard()
            return
        }
        guard !isHoldingTable, !isCollecting else { return }
        switch game.phase {
        case .discard:
            guard selected.count == 2, myCards.count == Game.dealtHandSize else { return }
            let cards = selected.map { myCards[$0] }
            hoveredCard = nil
            withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                game.discard(cards, by: .me)
                selected = []
            }
            publishEvents()
            driveOpponent()
        case .show(let step):
            if !isCountFinished {
                finishCount()
            } else if step != .crib {
                withAnimation(.spring(duration: 0.55, bounce: 0.2)) { game.advanceShow() }
                publishEvents()
            } else {
                collectAndDeal()
            }
        case .gameOver:
            if showsWinner {
                newGame()
            } else if !isCountFinished {
                finishCount()
            }
        case .play:
            break
        }
    }

    func hover(_ card: Card, isInside: Bool) {
        withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
            if isInside {
                hoveredCard = card
            } else if hoveredCard == card {
                hoveredCard = nil
            }
        }
    }

    private func stageMayHaveChanged(from old: Game) {
        let current = stage
        guard current != lastStage else { return }
        lastStage = current
        if old.phase == .play && game.phase != .play && !isStartingGame {
            holdTable()
        } else if case .show = game.phase {
            beginCount()
        } else if game.isOver {
            if showing != nil { beginCount() } else { celebrate() }
        }
        switch game.phase {
        case .discard:
            if dealCutStep == .done { deal() } else { dealtCount = 0 }
        case .play:
            playCut()
        case .show, .gameOver:
            break
        }
    }

    private func runDealCut() {
        let dealer = game.dealer
        let steps: [(DealCutStep, Int, Animation)] = [
            (.split, 550, .spring(duration: 0.45, bounce: 0.3)),
            (.revealed, 420, .spring(duration: 0.5, bounce: 0.25)),
            (.winner, 450, .spring(duration: 0.35, bounce: 0.5)),
            (.gather, 1_200, .spring(duration: 0.4, bounce: 0.2)),
            (.done, 380, .spring(duration: 0.75, bounce: 0.28)),
        ]
        run(.dealCut) { [weak self] in
            for (step, wait, animation) in steps {
                try? await Task.sleep(for: .milliseconds(wait))
                await self?.waitForBoard()
                guard !Task.isCancelled else { return }
                withAnimation(animation) { self?.dealCutStep = step }
                if step == .winner {
                    self?.showToast("low card · deals", color: Theme.color(for: dealer), duration: 1.5)
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.deal()
        }
    }

    private func deal() {
        dealtCount = 0
        shownCount = 0
        heldScores = nil
        countRevealed = 0
        run(.deal) { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            for count in 1...12 {
                await self?.waitForBoard()
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.45, bounce: 0.18)) { self?.dealtCount = count }
                try? await Task.sleep(for: .milliseconds(75))
            }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, self.game.phase == .discard else { return }
            let hand = self.game.hands[.bot, default: []]
            guard hand.count == Game.dealtHandSize else { return }
            let discard = Opponent.chooseDiscard(hand: hand, isDealer: self.game.dealer == .bot)
            withAnimation(.spring(duration: 0.55, bounce: 0.2)) { self.game.discard(discard, by: .bot) }
            self.publishEvents()
            self.driveOpponent()
        }
    }

    private func playCut() {
        cutStep = .deck
        displayRound = 0
        goTag = nil
        let steps: [(CutStep, Int, Animation)] = [
            (.split, 350, .spring(duration: 0.35, bounce: 0.25)),
            (.lift, 380, .easeOut(duration: 0.18)),
            (.reveal, 200, .spring(duration: 0.5, bounce: 0.25)),
            (.done, 650, .spring(duration: 0.4, bounce: 0.2)),
        ]
        run(.cut) { [weak self] in
            for (step, wait, animation) in steps {
                try? await Task.sleep(for: .milliseconds(wait))
                await self?.waitForBoard()
                guard !Task.isCancelled else { return }
                withAnimation(animation) { self?.cutStep = step }
            }
        }
    }

    private func driveOpponent() {
        jobs[.opponent]?.cancel()
        guard game.phase == .play, game.turn == .bot else { return }
        let delay = game.played.isEmpty ? 2_300 : 1_000
        run(.opponent) { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            await self?.waitForBoard()
            guard !Task.isCancelled else { return }
            self?.playOpponentCard()
        }
    }

    private func playOpponentCard() {
        guard game.phase == .play, game.turn == .bot,
              let card = Opponent.choosePlay(hand: game.inHand[.bot, default: []], sequence: game.sequence, count: game.count) else { return }
        finishPendingReset()
        let before = game.scores
        let landing = game.count + card.value
        withAnimation(.spring(duration: 0.6, bounce: 0.22)) { _ = game.play(card, by: .bot) }
        landCard(scoresBefore: before, landing: landing)
        driveOpponent()
    }

    private func finishPendingReset() {
        guard displayRound != game.round else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            shownCount = game.count
            displayRound = game.round
            goTag = nil
        }
    }

    private func landCard(scoresBefore: [Player: Int], landing: Int) {
        if heldScores == nil && scoresBefore != game.scores {
            heldScores = scoresBefore
        }
        let didReset = game.phase == .play && game.count != landing
        let round = game.round
        let count = game.count
        after(.milliseconds(200)) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(duration: 0.2, bounce: 0.3)) { self.shownCount = landing }
            if !self.isHoldingTable && self.game.phase == .play {
                withAnimation(.smooth(duration: 0.3)) { self.heldScores = nil }
            }
            self.publishEvents()
            if didReset { self.sweepPile(round: round, count: count) }
        }
    }

    private func sweepPile(round: Int, count: Int) {
        after(.milliseconds(950)) { [weak self] in
            guard let self, self.displayRound < round, self.game.phase == .play || self.isHoldingTable else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                self.displayRound = round
                self.goTag = nil
            }
            self.after(.milliseconds(500)) { [weak self] in
                guard let self, !self.game.played.contains(where: { $0.round >= round }) else { return }
                withAnimation(.spring(duration: 0.2, bounce: 0.3)) { self.shownCount = count }
            }
        }
    }

    private func holdTable() {
        isHoldingTable = true
        if let showing = game.showing ?? game.winningShowing {
            heldScores = game.scores
            heldScores?[showing.player, default: 0] -= showing.score.total
        }
        run(.hold) { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_600))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                self.isHoldingTable = false
                self.toast = nil
            }
            if self.showing != nil {
                self.beginCount()
            } else {
                self.heldScores = nil
                self.celebrate()
            }
        }
    }

    private func beginCount() {
        guard let showing else {
            jobs[.count]?.cancel()
            return
        }
        let items = showing.score.items
        let player = showing.player
        heldScores = game.scores
        heldScores?[player, default: 0] -= showing.score.total
        countRevealed = 0
        isCountFinished = false
        run(.count) { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            for (index, item) in items.enumerated() {
                await self?.waitForBoard()
                guard !Task.isCancelled, let self else { return }
                withAnimation(.spring(duration: 0.35, bounce: 0.35)) {
                    self.countRevealed = index + 1
                    self.heldScores?[player, default: 0] += item.points
                }
                self.pulse(.score(player))
                try? await Task.sleep(for: .milliseconds(720))
            }
            try? await Task.sleep(for: .milliseconds(items.isEmpty ? 700 : 250))
            guard !Task.isCancelled else { return }
            self?.finishCount()
        }
    }

    private func finishCount() {
        jobs[.count]?.cancel()
        guard let showing else { return }
        let skipped = countRevealed < showing.score.items.count
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            countRevealed = showing.score.items.count
            isCountFinished = true
            heldScores = nil
        }
        if skipped && showing.score.total > 0 { pulse(.score(showing.player)) }
        guard game.isOver else { return }
        run(.count) { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.celebrate()
        }
    }

    private func collectAndDeal() {
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) { isCollecting = true }
        run(.collect) { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            guard let self, !Task.isCancelled else { return }
            self.game.advanceShow()
            self.isCollecting = false
            self.publishEvents()
        }
    }

    private func celebrate() {
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showsWinner = true }
        celebrationStart = Date()
    }

    private func publishEvents() {
        let fresh = game.events.dropFirst(seenEvents)
        seenEvents = game.events.count
        let tableEvents = fresh.filter { !$0.reason.isShow }
        guard let colorEvent = tableEvents.last(where: { $0.points > 0 }) ?? tableEvents.last else { return }

        let heels = tableEvents.contains { $0.reason == .heels }
        if heels, heldScores == nil {
            heldScores = game.scores
            for event in tableEvents { heldScores?[event.player, default: 0] -= event.points }
        }

        if let go = tableEvents.last(where: { $0.reason == .saidGo }) {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { goTag = GoTag(player: go.player, count: shownCount) }
        }

        let text = tableEvents
            .map { $0.reason == .saidGo ? "go" : "+\($0.points) \($0.reason.label)" }
            .joined(separator: " · ")
        let scorers = Set(tableEvents.filter { $0.points > 0 }.map(\.player))
        let hitsCount = tableEvents.contains { event in
            guard case .pegging(let kind, _) = event.reason else { return false }
            return kind == .fifteen || kind == .thirtyOne
        }

        after(.seconds(heels ? 1.5 : 0)) { [weak self] in
            guard let self else { return }
            if heels { withAnimation(.smooth(duration: 0.3)) { self.heldScores = nil } }
            for player in [Player.me, .bot] where scorers.contains(player) {
                self.pulse(.score(player))
            }
            if hitsCount { self.pulse(.count) }
            self.showToast(text, color: Theme.color(for: colorEvent.player))
        }
    }

    private func pulse(_ target: Pulse) {
        withAnimation(.spring(duration: 0.2, bounce: 0.6)) { _ = pulses.insert(target) }
        after(.milliseconds(250)) { [weak self] in
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { _ = self?.pulses.remove(target) }
        }
    }

    private func showToast(_ text: String, color: Color, duration: Double = 1.6) {
        run(.toast) { [weak self] in
            withAnimation(.spring(duration: 0.35, bounce: 0.45)) { self?.toast = TableToast(text: text, color: color) }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil }
        }
    }

    private func waitForBoard() async {
        while !Task.isCancelled && isBoardShown {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func run(_ job: Job, _ body: @escaping @MainActor () async -> Void) {
        jobs[job]?.cancel()
        jobs[job] = Task { await body() }
    }

    private func after(_ delay: Duration, _ action: @escaping @MainActor () -> Void) {
        nextDelayedID += 1
        let id = nextDelayedID
        delayed[id] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.delayed[id] = nil
            action()
        }
    }

    private func cancelGameTasks() {
        for (job, task) in jobs where job != .demo { task.cancel() }
        delayed.values.forEach { $0.cancel() }
        delayed = [:]
    }
}
