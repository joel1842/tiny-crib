import CribbageCore
import SwiftUI

struct TableToast: Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

enum Pulse: Hashable {
    case score(Player)
    case count
}

enum CutStep {
    case deck, split, lift, reveal, done

    var showsFace: Bool { self == .reveal || self == .done }
    var lifted: Bool { self == .lift || self == .reveal }
    var isSplit: Bool { self == .split || self == .lift || self == .reveal }
}

enum DealCutStep {
    case centered, split, revealed, winner, gather, done

    var isOut: Bool { self == .split || self == .revealed || self == .winner }
    var faceUp: Bool { self == .revealed || self == .winner }
}

struct CountBeat {
    let kind: ScoreKind
    let points: Int
    let cards: Set<Card>
}

struct CountRow: Identifiable {
    let kind: ScoreKind
    let combos: [[Card]]
    let points: Int
    var id: ScoreKind { kind }
}

struct GoTag: Equatable {
    let player: Player
    let count: Int
}

@MainActor
public final class GameController: ObservableObject {
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
    private var lastStage = ""
    private var seenEvents = 0
    private var opponentTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var cutTask: Task<Void, Never>?
    private var dealTask: Task<Void, Never>?
    private var countTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var dealCutTask: Task<Void, Never>?
    private var holdTask: Task<Void, Never>?
    private var collectTask: Task<Void, Never>?
    private var isStartingGame = false
    private var generation = 0
    private var showingCache: (key: String, showing: Showing?, beats: [CountBeat]) = ("", nil, [])

    public init() {
        game = Game()
    }

    var myCards: [Card] {
        game.phase == .discard ? game.hands[.me, default: []] : game.inHand[.me, default: []]
    }

    var showing: Showing? {
        cachedShowing().showing
    }

    var countBeats: [CountBeat] {
        cachedShowing().beats
    }

    private func cachedShowing() -> (key: String, showing: Showing?, beats: [CountBeat]) {
        let key = "\(stage(of: game))-\(isHoldingTable)-\(isCollecting)"
        guard showingCache.key != key else { return showingCache }
        let showing: Showing? = if isHoldingTable || isCollecting {
            nil
        } else if let current = game.showing {
            current
        } else if game.isOver, let last = game.events.last, last.label == "hand" || last.label == "crib" {
            game.lastShowing
        } else {
            nil
        }
        let beats = showing?.score.items.map { CountBeat(kind: $0.kind, points: $0.points, cards: Set($0.cards)) } ?? []
        showingCache = (key, showing, beats)
        return showingCache
    }

    var countRows: [CountRow] {
        let revealed = countBeats.prefix(countRevealed)
        return ScoreKind.allCases.compactMap { kind in
            let beats = revealed.filter { $0.kind == kind }
            guard !beats.isEmpty else { return nil }
            let combos = beats.map { beat in
                beat.cards.sorted { ($0.rank, $0.suit.rawValue) < ($1.rank, $1.suit.rawValue) }
            }
            return CountRow(kind: kind, combos: combos, points: beats.reduce(0) { $0 + $1.points })
        }
    }

    var currentBeat: CountBeat? {
        let beats = countBeats
        guard countRevealed > 0, countRevealed <= beats.count, !isCountFinished else { return nil }
        return beats[countRevealed - 1]
    }

    var highlightedCards: Set<Card> {
        currentBeat?.cards ?? []
    }

    var revealedPoints: Int {
        countBeats.prefix(countRevealed).reduce(0) { $0 + $1.points }
    }

    var callout: String? {
        guard let beat = currentBeat else { return nil }
        let name = switch beat.kind {
        case .fifteen: "fifteen"
        case .pair: beat.points == 2 ? "pair" : beat.points == 6 ? "pair royal" : "double royal"
        case .run: "run"
        case .flush: "flush"
        case .nobs: "nobs"
        case .thirtyOne: "thirty-one"
        }
        return "\(name) +\(beat.points)"
    }

    public func toggleBoard() {
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) { isBoardShown.toggle() }
    }

    private func waitForBoard() async {
        while !Task.isCancelled && isBoardShown {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    func backPeg(_ player: Player) -> Int {
        game.backPegs[player] ?? 0
    }

    func displayedScore(_ player: Player) -> Int {
        heldScores?[player] ?? game.scores[player, default: 0]
    }

    public func newGame(seed: UInt64 = .random(in: .min ... .max)) {
        for task in [opponentTask, countTask, dealCutTask, dealTask, cutTask, holdTask, collectTask, toastTask] {
            task?.cancel()
        }
        gameNumber += 1
        generation += 1
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

    private func runDealCut() {
        let dealer = game.dealer
        let steps: [(DealCutStep, Int, Animation)] = [
            (.split, 550, .spring(duration: 0.45, bounce: 0.3)),
            (.revealed, 420, .spring(duration: 0.5, bounce: 0.25)),
            (.winner, 450, .spring(duration: 0.35, bounce: 0.5)),
            (.gather, 1_200, .spring(duration: 0.4, bounce: 0.2)),
            (.done, 380, .spring(duration: 0.75, bounce: 0.28)),
        ]
        dealCutTask = Task { [weak self] in
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

    public func runDemo(seed: UInt64) {
        newGame(seed: seed)
        demoTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1_100))
                switch self.game.phase {
                case .discard:
                    guard self.dealtCount == 12, self.myCards.count == 6 else { continue }
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
            guard dealtCount == 12, myCards.count == 6, myCards.indices.contains(index) else { return }
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
        default:
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
            guard selected.count == 2, myCards.count == 6 else { return }
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
                advanceToNextCount()
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

    private func advanceToNextCount() {
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) { game.advanceShow() }
        publishEvents()
    }

    private func collectAndDeal() {
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) { isCollecting = true }
        collectTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            guard let self, !Task.isCancelled else { return }
            self.game.advanceShow()
            self.isCollecting = false
            self.publishEvents()
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

    private func stage(of game: Game) -> String {
        let phase = switch game.phase {
        case .discard: "discard"
        case .play: "play"
        case .show(let step): "show\(step.rawValue)"
        case .gameOver: "over"
        }
        return "\(gameNumber)-\(game.handNumber)-\(phase)"
    }

    private func stageMayHaveChanged(from old: Game) {
        let current = stage(of: game)
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
        case .play: playCut()
        default: break
        }
    }

    private func deal() {
        dealTask?.cancel()
        dealtCount = 0
        shownCount = 0
        heldScores = nil
        countRevealed = 0

        dealTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            for count in 1...12 {
                await self?.waitForBoard()
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.45, bounce: 0.18)) { self?.dealtCount = count }
                try? await Task.sleep(for: .milliseconds(75))
            }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, self.game.phase == .discard,
                  self.game.hands[.them, default: []].count == 6 else { return }
            let hand = self.game.hands[.them, default: []]
            let discard = Opponent.chooseDiscard(hand: hand, isDealer: self.game.dealer == .them)
            withAnimation(.spring(duration: 0.55, bounce: 0.2)) { self.game.discard(discard, by: .them) }
            self.publishEvents()
            self.driveOpponent()
        }
    }

    private func holdTable() {
        isHoldingTable = true
        let winningCount = game.isOver && game.events.last.map { $0.label == "hand" || $0.label == "crib" } == true
        if let showing = game.showing ?? (winningCount ? game.lastShowing : nil) {
            heldScores = game.scores
            heldScores?[showing.player, default: 0] -= showing.score.total
        }
        holdTask = Task { [weak self] in
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

    private func celebrate() {
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showsWinner = true }
        celebrationStart = Date()
    }

    private func beginCount() {
        countTask?.cancel()
        guard let showing else { return }
        let beats = showing.score.items
        let player = showing.player
        heldScores = game.scores
        heldScores?[player, default: 0] -= showing.score.total
        countRevealed = 0
        isCountFinished = false
        countTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            for (index, beat) in beats.enumerated() {
                await self?.waitForBoard()
                guard !Task.isCancelled, let self else { return }
                withAnimation(.spring(duration: 0.35, bounce: 0.35)) {
                    self.countRevealed = index + 1
                    self.heldScores?[player, default: 0] += beat.points
                }
                self.pulse(.score(player))
                try? await Task.sleep(for: .milliseconds(720))
            }
            try? await Task.sleep(for: .milliseconds(beats.isEmpty ? 700 : 250))
            guard !Task.isCancelled else { return }
            self?.finishCount()
        }
    }

    private func finishCount() {
        countTask?.cancel()
        guard let showing else { return }
        let skipped = countRevealed < showing.score.items.count
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            countRevealed = showing.score.items.count
            isCountFinished = true
            heldScores = nil
        }
        if skipped && showing.score.total > 0 { pulse(.score(showing.player)) }
        if game.isOver {
            countTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                self?.celebrate()
            }
        }
    }

    private func playCut() {
        cutTask?.cancel()
        cutStep = .deck
        displayRound = 0
        goTag = nil
        let steps: [(CutStep, Int, Animation)] = [
            (.split, 350, .spring(duration: 0.35, bounce: 0.25)),
            (.lift, 380, .easeOut(duration: 0.18)),
            (.reveal, 200, .spring(duration: 0.5, bounce: 0.25)),
            (.done, 650, .spring(duration: 0.4, bounce: 0.2)),
        ]
        cutTask = Task { [weak self] in
            for (step, wait, animation) in steps {
                try? await Task.sleep(for: .milliseconds(wait))
                await self?.waitForBoard()
                guard !Task.isCancelled else { return }
                withAnimation(animation) { self?.cutStep = step }
            }
        }
    }

    private func driveOpponent() {
        opponentTask?.cancel()
        guard game.phase == .play, game.turn == .them else { return }
        let delay = game.played.isEmpty ? 2_300 : 1_000
        opponentTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            await self?.waitForBoard()
            guard !Task.isCancelled, let self else { return }
            self.playOpponentCard()
        }
    }

    private func playOpponentCard() {
        guard game.phase == .play, game.turn == .them else { return }
        let hand = game.inHand[.them, default: []]
        guard let card = Opponent.choosePlay(hand: hand, sequence: game.sequence, count: game.count) else { return }
        finishPendingReset()
        let before = game.scores
        let landing = game.count + card.value
        withAnimation(.spring(duration: 0.6, bounce: 0.22)) { _ = game.play(card, by: .them) }
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
        let generation = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.generation == generation else { return }
            withAnimation(.spring(duration: 0.2, bounce: 0.3)) { self.shownCount = landing }
            if !self.isHoldingTable && self.game.phase == .play {
                withAnimation(.smooth(duration: 0.3)) { self.heldScores = nil }
            }
            self.publishEvents()
            guard didReset else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                guard self.generation == generation, self.displayRound < round,
                      self.game.phase == .play || self.isHoldingTable else { return }
                withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                    self.displayRound = round
                    self.goTag = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard self.generation == generation, !self.game.played.contains(where: { $0.round >= round }) else { return }
                    withAnimation(.spring(duration: 0.2, bounce: 0.3)) { self.shownCount = count }
                }
            }
        }
    }

    private func publishEvents() {
        let fresh = Array(game.events.dropFirst(seenEvents))
        seenEvents = game.events.count
        let tableEvents = fresh.filter { $0.label != "hand" && $0.label != "crib" }
        guard !tableEvents.isEmpty else { return }

        let heels = tableEvents.contains { $0.label == "his heels" }
        let delay = heels ? 1.5 : 0
        if heels, heldScores == nil {
            heldScores = game.scores
            for event in tableEvents { heldScores?[event.player, default: 0] -= event.points }
        }

        if let go = tableEvents.last(where: { $0.points == 0 }) {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { goTag = GoTag(player: go.player, count: shownCount) }
        }

        let text = tableEvents.map { event in
            event.points > 0 ? "+\(event.points) \(event.label)" : "go"
        }.joined(separator: " · ")
        let color = Theme.color(for: (tableEvents.last(where: { $0.points > 0 }) ?? tableEvents.last!).player)
        let generation = generation

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == generation else { return }
            if heels { withAnimation(.smooth(duration: 0.3)) { self.heldScores = nil } }
            for player in [Player.me, .them] where tableEvents.contains(where: { $0.player == player && $0.points > 0 }) {
                self.pulse(.score(player))
            }
            if tableEvents.contains(where: { $0.label == "fifteen" || $0.label == "thirty-one" }) {
                self.pulse(.count)
            }
            self.showToast(text, color: color)
        }
    }

    private func pulse(_ target: Pulse) {
        withAnimation(.spring(duration: 0.2, bounce: 0.6)) { _ = pulses.insert(target) }
        let generation = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard self?.generation == generation else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { _ = self?.pulses.remove(target) }
        }
    }

    private func showToast(_ text: String, color: Color, delay: Double = 0, duration: Double = 1.6) {
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.45)) { self?.toast = TableToast(text: text, color: color) }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil }
        }
    }
}
