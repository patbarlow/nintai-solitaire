import Foundation
import SwiftUI

@MainActor
class GameState: ObservableObject {
    @Published var stock: [Card] = []
    @Published var waste: [Card] = []
    @Published var tableau: [[Card]] = Array(repeating: [], count: 7)
    @Published var foundations: [[Card]] = Array(repeating: [], count: 4)
    @Published var moves: Int = 0
    @Published var gameWon: Bool = false
    @Published var startTime: Date?
    @Published var noMovesLeft: Bool = false
    
    init() {
        newGame()
    }
    
    func newGame() {
        clearSavedGameState()
        let deck = Card.createDeck()
        stock = []
        waste = []
        tableau = Array(repeating: [], count: 7)
        foundations = Array(repeating: [], count: 4)
        moves = 0
        gameWon = false
        noMovesLeft = false
        startTime = Date()
        
        var cardIndex = 0
        
        for column in 0..<7 {
            for row in 0...column {
                let card = Card(suit: deck[cardIndex].suit, rank: deck[cardIndex].rank, isFaceUp: row == column)
                tableau[column].append(card)
                cardIndex += 1
            }
        }
        
        for i in cardIndex..<deck.count {
            stock.append(deck[i])
        }
        
        // Initial check for no moves
        Task {
            await checkForNoMoves()
        }
    }
    
    func drawFromStock() {
        guard !stock.isEmpty else {
            if !waste.isEmpty {
                stock = waste.reversed().map { card in
                    Card(suit: card.suit, rank: card.rank, isFaceUp: false)
                }
                waste = []
            }
            return
        }
        
        // Draw 3 cards at a time (or remaining cards if less than 3)
        let cardsToDraw = min(3, stock.count)
        for _ in 0..<cardsToDraw {
            let card = stock.removeLast()
            let faceUpCard = Card(suit: card.suit, rank: card.rank, isFaceUp: true)
            waste.append(faceUpCard)
        }
        moves += 1
        saveGameState()
        
        Task {
            await checkForNoMoves()
        }
    }
    
    func canMoveCard(from source: Card, to destination: Card?) -> Bool {
        guard let dest = destination else {
            return source.rank == .king
        }
        
        return source.rank.rawValue == dest.rank.rawValue - 1 && 
               source.color != dest.color
    }
    
    func canMoveToFoundation(card: Card, foundationIndex: Int) -> Bool {
        let foundation = foundations[foundationIndex]
        
        if foundation.isEmpty {
            return card.rank == .ace
        }
        
        guard let topCard = foundation.last else { return false }
        return card.suit == topCard.suit && 
               card.rank.rawValue == topCard.rank.rawValue + 1
    }
    
    func findAvailableFoundationForAce(card: Card) -> Int? {
        guard card.rank == .ace else { return nil }
        
        // Find any empty foundation slot for the ace
        for (index, foundation) in foundations.enumerated() {
            if foundation.isEmpty {
                return index
            }
        }
        return nil
    }
    
    func moveToFoundation(card: Card, foundationIndex: Int) {
        foundations[foundationIndex].append(card)
        moves += 1
        saveGameState()
        checkForWin()
        
        Task {
            await checkForNoMoves()
        }
    }
    
    func moveCards(from sourceColumn: Int, cardIndex: Int, to destColumn: Int) {
        let cardsToMove = Array(tableau[sourceColumn].suffix(from: cardIndex))
        tableau[sourceColumn].removeLast(cardsToMove.count)
        tableau[destColumn].append(contentsOf: cardsToMove)
        
        if !tableau[sourceColumn].isEmpty && !tableau[sourceColumn].last!.isFaceUp {
            tableau[sourceColumn][tableau[sourceColumn].count - 1].isFaceUp = true
        }
        
        moves += 1
        saveGameState()
        
        Task {
            await checkForNoMoves()
        }
    }
    
    private func checkForWin() {
        let wasWon = gameWon
        gameWon = foundations.allSatisfy { $0.count == 13 }
        if gameWon && !wasWon {
            clearSavedGameState()
        }
    }
    
    // Check for available moves
    func checkForNoMoves() async {
        // Don't check for no moves if the game is already won
        if gameWon {
            await MainActor.run {
                if self.noMovesLeft != false {
                    self.noMovesLeft = false
                }
            }
            return
        }
        
        // First check for auto-completion opportunity
        await checkForAutoCompletion()
        
        // If game was won during auto-completion, don't check for no moves
        if gameWon {
            await MainActor.run {
                if self.noMovesLeft != false {
                    self.noMovesLeft = false
                }
            }
            return
        }
        
        // If we can still draw from stock or recycle waste, we have moves
        if !stock.isEmpty || (!waste.isEmpty && stock.isEmpty) {
            await MainActor.run {
                if self.noMovesLeft != false { 
                    self.noMovesLeft = false 
                }
            }
            return
        }
        
        // Check moves from waste to foundations
        if let topWasteCard = waste.last {
            for i in 0..<4 {
                if canMoveToFoundation(card: topWasteCard, foundationIndex: i) {
                    await MainActor.run {
                        if self.noMovesLeft != false { self.noMovesLeft = false }
                    }
                    return
                }
            }
        }
        
        // Check moves from waste to tableau
        if let topWasteCard = waste.last {
            for i in 0..<7 {
                if canMoveCard(from: topWasteCard, to: tableau[i].last) {
                    await MainActor.run {
                        if self.noMovesLeft != false { self.noMovesLeft = false }
                    }
                    return
                }
            }
        }
        
        // Check moves from tableau to foundations
        for i in 0..<7 {
            if let topTableauCard = tableau[i].last, topTableauCard.isFaceUp {
                for j in 0..<4 {
                    if canMoveToFoundation(card: topTableauCard, foundationIndex: j) {
                        await MainActor.run {
                            if self.noMovesLeft != false { self.noMovesLeft = false }
                        }
                        return
                    }
                }
            }
        }

        // Check for moves between tableau columns (properly check all valid sequences)
        for sourceCol in 0..<7 {
            let sourceColumn = tableau[sourceCol]
            
            // Find all face-up cards that could be moved as sequences
            for startIndex in 0..<sourceColumn.count {
                let card = sourceColumn[startIndex]
                if !card.isFaceUp { continue }
                
                // Check if this card can start a valid sequence to move
                var isValidSequence = true
                for seqIndex in startIndex..<sourceColumn.count - 1 {
                    let current = sourceColumn[seqIndex]
                    let next = sourceColumn[seqIndex + 1]
                    if next.rank.rawValue != current.rank.rawValue - 1 || next.color == current.color {
                        isValidSequence = false
                        break
                    }
                }
                
                if isValidSequence {
                    // Try to move this sequence to any other column
                    for destCol in 0..<7 where destCol != sourceCol {
                        if canMoveCard(from: card, to: tableau[destCol].last) {
                            await MainActor.run {
                                if self.noMovesLeft != false { self.noMovesLeft = false }
                            }
                            return
                        }
                    }
                }
            }
        }
        
        // If we got here, no moves are left
        await MainActor.run {
            if self.noMovesLeft != true {
                self.noMovesLeft = true
            }
        }
    }
    
    // Auto-completion when all cards are face-up
    @MainActor
    func checkForAutoCompletion() async {
        // Check if all tableau cards are face-up
        let allTableauFaceUp = tableau.allSatisfy { column in
            column.allSatisfy { $0.isFaceUp }
        }
        
        // All cards must be revealed (stock empty, all tableau face-up)
        // Waste cards are always face-up when drawn
        guard allTableauFaceUp && stock.isEmpty else { return }
        
        // Start auto-completion
        var foundMove = true
        while foundMove && !gameWon {
            foundMove = false
            
            // Try to move cards from tableau to foundations
            for colIndex in 0..<7 {
                if let topCard = tableau[colIndex].last {
                    for foundIndex in 0..<4 {
                        if canMoveToFoundation(card: topCard, foundationIndex: foundIndex) {
                            // Perform the move with animation delay
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            
                            tableau[colIndex].removeLast()
                            foundations[foundIndex].append(topCard)
                            moves += 1
                            saveGameState()
                            checkForWin()
                            
                            foundMove = true
                            break
                        }
                    }
                    if foundMove { break }
                }
            }
            
            // Try to move cards from waste to foundations
            if !foundMove, let topWasteCard = waste.last {
                for foundIndex in 0..<4 {
                    if canMoveToFoundation(card: topWasteCard, foundationIndex: foundIndex) {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        
                        waste.removeLast()
                        foundations[foundIndex].append(topWasteCard)
                        moves += 1
                        saveGameState()
                        checkForWin()
                        
                        foundMove = true
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Persistence
    func saveGameState() {
        let gameData: [String: Any] = [
            "stock": stock.map { ["suit": $0.suit.rawValue, "rank": $0.rank.rawValue, "isFaceUp": $0.isFaceUp] },
            "waste": waste.map { ["suit": $0.suit.rawValue, "rank": $0.rank.rawValue, "isFaceUp": $0.isFaceUp] },
            "tableau": tableau.map { column in
                column.map { ["suit": $0.suit.rawValue, "rank": $0.rank.rawValue, "isFaceUp": $0.isFaceUp] }
            },
            "foundations": foundations.map { column in
                column.map { ["suit": $0.suit.rawValue, "rank": $0.rank.rawValue, "isFaceUp": $0.isFaceUp] }
            },
            "moves": moves,
            "gameWon": gameWon,
            "startTime": startTime?.timeIntervalSince1970 as Any,
            "noMovesLeft": noMovesLeft
        ]
        
        UserDefaults.standard.set(gameData, forKey: "savedGameState")
    }
    
    static func loadGameState() -> GameState? {
        guard let gameData = UserDefaults.standard.dictionary(forKey: "savedGameState") else {
            return nil
        }
        
        let gameState = GameState()
        
        // Load stock
        if let stockData = gameData["stock"] as? [[String: Any]] {
            gameState.stock = stockData.compactMap { cardData in
                guard let suitRaw = cardData["suit"] as? String,
                      let rankRaw = cardData["rank"] as? Int,
                      let isFaceUp = cardData["isFaceUp"] as? Bool,
                      let suit = Suit(rawValue: suitRaw),
                      let rank = Rank(rawValue: rankRaw) else {
                    return nil
                }
                return Card(suit: suit, rank: rank, isFaceUp: isFaceUp)
            }
        }
        
        // Load waste
        if let wasteData = gameData["waste"] as? [[String: Any]] {
            gameState.waste = wasteData.compactMap { cardData in
                guard let suitRaw = cardData["suit"] as? String,
                      let rankRaw = cardData["rank"] as? Int,
                      let isFaceUp = cardData["isFaceUp"] as? Bool,
                      let suit = Suit(rawValue: suitRaw),
                      let rank = Rank(rawValue: rankRaw) else {
                    return nil
                }
                return Card(suit: suit, rank: rank, isFaceUp: isFaceUp)
            }
        }
        
        // Load tableau
        if let tableauData = gameData["tableau"] as? [[[String: Any]]] {
            gameState.tableau = tableauData.map { columnData in
                columnData.compactMap { cardData in
                    guard let suitRaw = cardData["suit"] as? String,
                          let rankRaw = cardData["rank"] as? Int,
                          let isFaceUp = cardData["isFaceUp"] as? Bool,
                          let suit = Suit(rawValue: suitRaw),
                          let rank = Rank(rawValue: rankRaw) else {
                        return nil
                    }
                    return Card(suit: suit, rank: rank, isFaceUp: isFaceUp)
                }
            }
        }
        
        // Load foundations
        if let foundationsData = gameData["foundations"] as? [[[String: Any]]] {
            gameState.foundations = foundationsData.map { columnData in
                columnData.compactMap { cardData in
                    guard let suitRaw = cardData["suit"] as? String,
                          let rankRaw = cardData["rank"] as? Int,
                          let isFaceUp = cardData["isFaceUp"] as? Bool,
                          let suit = Suit(rawValue: suitRaw),
                          let rank = Rank(rawValue: rankRaw) else {
                        return nil
                    }
                    return Card(suit: suit, rank: rank, isFaceUp: isFaceUp)
                }
            }
        }
        
        // Load other properties
        gameState.moves = gameData["moves"] as? Int ?? 0
        gameState.gameWon = gameData["gameWon"] as? Bool ?? false
        gameState.noMovesLeft = gameData["noMovesLeft"] as? Bool ?? false
        
        if let startTimeInterval = gameData["startTime"] as? TimeInterval {
            gameState.startTime = Date(timeIntervalSince1970: startTimeInterval)
        }
        
        return gameState
    }
    
    func clearSavedGameState() {
        UserDefaults.standard.removeObject(forKey: "savedGameState")
    }
}
