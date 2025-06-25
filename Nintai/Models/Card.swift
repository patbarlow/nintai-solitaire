import Foundation

enum Suit: String, CaseIterable {
    case hearts = "♥"
    case diamonds = "♦"
    case clubs = "♣"
    case spades = "♠"
    
    var assetName: String {
        switch self {
        case .hearts: "heart"
        case .diamonds: "diamond"
        case .clubs: "club"
        case .spades: "spade"
        }
    }
    
    var color: CardColor {
        switch self {
        case .hearts, .diamonds:
            return .red
        case .clubs, .spades:
            return .black
        }
    }
}

enum CardColor {
    case red
    case black
}

enum Rank: Int, CaseIterable {
    case ace = 1
    case two, three, four, five, six, seven, eight, nine, ten
    case jack = 11
    case queen = 12
    case king = 13
    
    var displayValue: String {
        switch self {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return String(rawValue)
        }
    }
}

struct Card: Identifiable, Equatable, Hashable {
    let id = UUID()
    let suit: Suit
    let rank: Rank
    var isFaceUp: Bool = false
    
    var color: CardColor {
        suit.color
    }
    
    var isRed: Bool {
        color == .red
    }
    
    var isBlack: Bool {
        color == .black
    }
    
    init(suit: Suit, rank: Rank, isFaceUp: Bool = false) {
        self.suit = suit
        self.rank = rank
        self.isFaceUp = isFaceUp
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.suit == rhs.suit && lhs.rank == rhs.rank
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(suit)
        hasher.combine(rank)
    }
}

extension Card {
    static func createDeck() -> [Card] {
        var deck: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                deck.append(Card(suit: suit, rank: rank))
            }
        }
        return deck.shuffled()
    }
}