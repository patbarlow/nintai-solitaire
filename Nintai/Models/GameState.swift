import Foundation
import SwiftUI

@MainActor
class GameState: ObservableObject {
    @Published var stock: [Card] = []
    @Published var waste: [Card] = []
    @Published var tableau: [[Card]] = Array(repeating: [], count: 7)
    @Published var foundations: [[Card]] = Array(repeating: [], count: 4)
    @Published var score: Int = 0
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
        score = 0
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
        score += 10
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
            score += 5
        }
        
        moves += 1
        
        Task {
            await checkForNoMoves()
        }
    }
    
    private func checkForWin() {
        let wasWon = gameWon
        gameWon = foundations.allSatisfy { $0.count == 13 }
        if gameWon && !wasWon {
            score += 1000
        }
    }
    
    // Check for available moves
    func checkForNoMoves() async {
        // If there are cards in the stock, there's always a move
        if !stock.isEmpty {
            if self.noMovesLeft != false {
                self.noMovesLeft = false
            }
            return
        }
        
        // If stock is empty but waste can be recycled, there's a move
        if stock.isEmpty && !waste.isEmpty && tableau.allSatisfy({ $0.isEmpty }) {
            // This condition is a bit simplistic, but if you can recycle, that's a move.
            // A more complex check would see if recycling *would* create a move.
            // For now, we'll count recycling as a potential move.
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
        
        // If we got here, no moves are left
        if self.noMovesLeft != true {
            self.noMovesLeft = true
        }
    }
}