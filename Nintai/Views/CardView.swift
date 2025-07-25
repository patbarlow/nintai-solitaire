import SwiftUI

struct CardView: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    
    init(card: Card, width: CGFloat = 45, height: CGFloat = 63) {
        self.card = card
        self.width = width
        self.height = height
    }
    
    var body: some View {
        ZStack {
            // Enhanced card background with depth
            RoundedRectangle(cornerRadius: width * 0.13)
                .fill(card.isFaceUp ? AnyShapeStyle(Color.white) : AnyShapeStyle(cardBackGradient))
                .frame(width: width, height: height)
                .overlay {
                    // Simple border
                    RoundedRectangle(cornerRadius: width * 0.13)
                        .stroke(
                            card.isFaceUp 
                                ? Color.gray.opacity(0.3)
                                : Color.white.opacity(0.5),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)

            if card.isFaceUp {
                cardFront
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: width * 0.13))
            } else {
                cardBack
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }
    
    private var cardBackGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.9, green: 0.25, blue: 0.25),
                Color(red: 0.7, green: 0.15, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBack: some View {
        ZStack {
            // Enhanced decorative border with depth
            RoundedRectangle(cornerRadius: width * 0.09)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .padding(width * 0.09)
            
            // Enhanced inner pattern
            RoundedRectangle(cornerRadius: width * 0.07)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.7), Color.white.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
                .padding(width * 0.13)
            
            // Enhanced center diamond pattern with depth
            VStack(spacing: width * 0.04) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: width * 0.04) {
                        ForEach(0..<3, id: \.self) { col in
                            Diamond()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: width * 0.08, height: width * 0.08)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0.5, y: 0.5)
                        }
                    }
                }
            }
        }
    }
    
    private var cardFront: some View {
        VStack {
            HStack {
                Text(card.rank.displayValue)
                    .font(.system(size: rankFontSize, weight: .semibold))
                    .foregroundColor(card.isRed ? .red : .black)
                Spacer()
            }
            
            Spacer()
            
            HStack {
                Spacer()
                SuitSymbol(suit: card.suit, size: suitFontSize)
            }
        }
        .padding(width * 0.1)
    }
    
    private var rankFontSize: CGFloat {
        width * 0.45
    }
    
    private var suitFontSize: CGFloat {
        width * 0.55
    }
}

extension Color {
    static let softRed = Color(red: 0.9, green: 0.3, blue: 0.3)
}

struct SuitSymbol: View {
    let suit: Suit
    let size: CGFloat
    
    var body: some View {
        Image(systemName: suit.symbolName)
            .font(.system(size: size))
            .foregroundColor(suit.color.swiftUIColor)
    }
}

extension CardColor {
    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .black: return .black
        }
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct EmptyCardSlot: View {
    let width: CGFloat
    let height: CGFloat
    
    init(width: CGFloat = 45, height: CGFloat = 63) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.13)
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.13)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .frame(width: width, height: height)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 10) {
            CardView(card: Card(suit: .hearts, rank: .ace, isFaceUp: true))
            CardView(card: Card(suit: .spades, rank: .king, isFaceUp: true))
            CardView(card: Card(suit: .diamonds, rank: .queen, isFaceUp: true))
            CardView(card: Card(suit: .clubs, rank: .jack, isFaceUp: true))
        }
        
        HStack(spacing: 10) {
            CardView(card: Card(suit: .hearts, rank: .ten, isFaceUp: false))
            CardView(card: Card(suit: .diamonds, rank: .five, isFaceUp: true))
            CardView(card: Card(suit: .spades, rank: .ace, isFaceUp: true))
            CardView(card: Card(suit: .clubs, rank: .king, isFaceUp: true))
            EmptyCardSlot()
        }
        
        // Test different sizes
        HStack(spacing: 10) {
            CardView(card: Card(suit: .hearts, rank: .seven, isFaceUp: true), width: 60, height: 84)
            CardView(card: Card(suit: .spades, rank: .three, isFaceUp: true), width: 80, height: 112)
        }
    }
    .padding()
    .background(Color.green.opacity(0.3))
}
