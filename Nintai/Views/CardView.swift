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
            // Card background
            RoundedRectangle(cornerRadius: width * 0.13)
                .fill(card.isFaceUp ? Color.white : cardBackColor)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.13)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

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
    
    private var cardBackColor: Color {
        Color(red: 0.8, green: 0.2, blue: 0.2)
    }
    
    private var cardBack: some View {
        ZStack {
            // Decorative border
            RoundedRectangle(cornerRadius: width * 0.09)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                .padding(width * 0.09)
            
            // Inner pattern
            RoundedRectangle(cornerRadius: width * 0.07)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                .padding(width * 0.13)
            
            // Center diamond pattern
            VStack(spacing: width * 0.04) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: width * 0.04) {
                        ForEach(0..<3, id: \.self) { _ in
                            Diamond()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: width * 0.08, height: width * 0.08)
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
                Spacer()
            }
            
            Spacer()
            
            HStack {
                Spacer()
                SuitSymbol(suit: card.suit, size: suitFontSize)
            }
        }
        .padding(width * 0.1)
        .foregroundColor(card.isRed ? .softRed : .black)
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
        Image(suit.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
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
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            .fill(Color.clear)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
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
