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
        checkForWin()
        
        Task {
            await checkForNoMoves()
        }
    }
    
    func moveCards(from sourceColumn: Int, cardIndex: Int, to destColumn: Int) {
        let cardsToMove = Array(tableau[sourceColumn].suffix(from: cardIndex))
        tableau[sourceColumn].removeLast(cardsToMove.count)
        tableau[destColumn].append(contentsOf: cardsToMove)
        
        if let lastCard = tableau[sourceColumn].last, !lastCard.isFaceUp {
            let faceUpCard = Card(suit: lastCard.suit, rank: lastCard.rank, isFaceUp: true)
            tableau[sourceColumn][tableau[sourceColumn].count - 1] = faceUpCard
        }
        
        moves += 1
        
        Task {
            await checkForNoMoves()
        }
    }
    
    private func checkForWin() {
        _ = gameWon
        gameWon = foundations.allSatisfy { $0.count == 13 }
    }
    
    // Check for available moves
    func checkForNoMoves() async {
        // Don't check for no moves if the game is already won
        if gameWon {
            if self.noMovesLeft != false {
                self.noMovesLeft = false
            }
            return
        }
        // Check moves from waste to foundations
        if let topWasteCard = waste.last {
            for i in 0..<4 {
                if canMoveToFoundation(card: topWasteCard, foundationIndex: i) {
                    if self.noMovesLeft != false { self.noMovesLeft = false }
                    return
                }
            }
        }
        
        // Check moves from waste to tableau
        if let topWasteCard = waste.last {
            for i in 0..<7 {
                if canMoveCard(from: topWasteCard, to: tableau[i].last) {
                     if self.noMovesLeft != false { self.noMovesLeft = false }
                    return
                }
            }
        }
        
        // Check moves from tableau to foundations
        for i in 0..<7 {
            if let topTableauCard = tableau[i].last, topTableauCard.isFaceUp {
                for j in 0..<4 {
                    if canMoveToFoundation(card: topTableauCard, foundationIndex: j) {
                        if self.noMovesLeft != false { self.noMovesLeft = false }
                        return
                    }
                }
            }
        }

        // Check for moves between tableau columns
        for i in 0..<7 {
            if let sourceCard = tableau[i].first(where: { $0.isFaceUp }) {
                for j in 0..<7 where i != j {
                    if canMoveCard(from: sourceCard, to: tableau[j].last) {
                        if self.noMovesLeft != false { self.noMovesLeft = false }
                        return
                    }
                }
            }
        }
        
        // Check all cards in stock (draw pile) for potential moves
        for stockCard in stock {
            let faceUpCard = Card(suit: stockCard.suit, rank: stockCard.rank, isFaceUp: true)
            
            // Check if this stock card can move to any foundation
            for i in 0..<4 {
                if canMoveToFoundation(card: faceUpCard, foundationIndex: i) {
                    if self.noMovesLeft != false { self.noMovesLeft = false }
                    return
                }
            }
            
            // Check if this stock card can move to any tableau column
            for i in 0..<7 {
                if canMoveCard(from: faceUpCard, to: tableau[i].last) {
                    if self.noMovesLeft != false { self.noMovesLeft = false }
                    return
                }
            }
        }
        
        // If stock is empty but waste can be recycled, check if recycling would create moves
        if stock.isEmpty && !waste.isEmpty {
            // Simulate recycling: all waste cards become stock (face down)
            let recycledStock = waste.reversed()
            
            // Check if any recycled card could create a move
            for card in recycledStock {
                let faceUpCard = Card(suit: card.suit, rank: card.rank, isFaceUp: true)
                
                // Check foundations
                for i in 0..<4 {
                    if canMoveToFoundation(card: faceUpCard, foundationIndex: i) {
                        if self.noMovesLeft != false { self.noMovesLeft = false }
                        return
                    }
                }
                
                // Check tableau
                for i in 0..<7 {
                    if canMoveCard(from: faceUpCard, to: tableau[i].last) {
                        if self.noMovesLeft != false { self.noMovesLeft = false }
                        return
                    }
                }
            }
        }
        
        // If we got here, no moves are left
        if self.noMovesLeft != true {
            self.noMovesLeft = true
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
