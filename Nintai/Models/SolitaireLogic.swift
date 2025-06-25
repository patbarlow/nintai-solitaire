import Foundation

struct SolitaireLogic {
    static func isValidTableauMove(card: Card, onto targetCard: Card?) -> Bool {
        guard let target = targetCard else {
            return card.rank == .king
        }
        
        return card.rank.rawValue == target.rank.rawValue - 1 && 
               card.color != target.color
    }
    
    static func isValidFoundationMove(card: Card, onto foundation: [Card]) -> Bool {
        if foundation.isEmpty {
            return card.rank == .ace
        }
        
        guard let topCard = foundation.last else { return false }
        return card.suit == topCard.suit && 
               card.rank.rawValue == topCard.rank.rawValue + 1
    }
    
    static func getMovableCards(from tableau: [Card], startingAt index: Int) -> [Card] {
        guard index < tableau.count else { return [] }
        
        let cards = Array(tableau.suffix(from: index))
        
        for i in 1..<cards.count {
            let current = cards[i]
            let previous = cards[i-1]
            
            if current.rank.rawValue != previous.rank.rawValue - 1 || 
               current.color == previous.color {
                return Array(cards.prefix(i))
            }
        }
        
        return cards
    }
    
    @MainActor
    static func findAutoMoves(gameState: GameState) -> [(card: Card, foundation: Int)]? {
        var autoMoves: [(card: Card, foundation: Int)] = []
        
        for card in gameState.waste {
            for (index, foundation) in gameState.foundations.enumerated() {
                if isValidFoundationMove(card: card, onto: foundation) {
                    autoMoves.append((card: card, foundation: index))
                }
            }
        }
        
        for column in gameState.tableau {
            if let topCard = column.last, topCard.isFaceUp {
                for (index, foundation) in gameState.foundations.enumerated() {
                    if isValidFoundationMove(card: topCard, onto: foundation) {
                        autoMoves.append((card: topCard, foundation: index))
                    }
                }
            }
        }
        
        return autoMoves.isEmpty ? nil : autoMoves
    }
    
    static func calculateScore(moves: Int, time: TimeInterval, gameWon: Bool) -> Int {
        var score = 0
        
        if gameWon {
            score += 1000
            
            let timeBonus = max(0, 1000 - Int(time / 60) * 10)
            score += timeBonus
            
            let movesPenalty = max(0, moves - 100) * 2
            score -= movesPenalty
        }
        
        return max(0, score)
    }
}