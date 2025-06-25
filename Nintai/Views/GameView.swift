import SwiftUI

struct FramePreferenceData: Equatable {
    enum ViewType {
        case foundation, tableau
    }
    let viewType: ViewType
    let index: Int
    let frame: CGRect
}

struct FramePreferenceKey: PreferenceKey {
    typealias Value = [FramePreferenceData]
    static var defaultValue: [FramePreferenceData] = []
    static func reduce(value: inout [FramePreferenceData], nextValue: () -> [FramePreferenceData]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

class HapticManager {
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    func cardPickup() {
        impactLight.impactOccurred()
    }
    
    func cardMove() {
        impactMedium.impactOccurred()
    }
    
    func cardFlip() {
        selectionFeedback.selectionChanged()
    }
    
    func gameWin() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func invalidMove() {
        notificationFeedback.notificationOccurred(.error)
    }
}

struct GameView: View {
    @StateObject private var gameState = GameState()
    @State private var selectedCard: Card?
    @State private var selectedFromColumn: Int?
    @State private var selectedCardIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var dragInitialOffset: CGSize = .zero
    @State private var foundationFrames: [CGRect] = Array(repeating: .zero, count: 4)
    @State private var tableauFrames: [CGRect] = Array(repeating: .zero, count: 7)
    
    // Confirmation States
    @State private var showNewGameConfirmation = false
    @State private var showNoMovesAlert = false
    
    // Dynamic sizing based on screen width
    @State private var cardWidth: CGFloat = 45
    @State private var cardHeight: CGFloat = 63
    
    let cardAspectRatio: CGFloat = 63.0 / 45.0 // height / width
    let horizontalPadding: CGFloat = 5 // Padding on either side
    let columnSpacing: CGFloat = 8 // Space between columns
    
    var body: some View {
        GeometryReader { geometry in
            ZStack { // Outer ZStack for layering modals over the game
                ZStack { // Original ZStack for game content
                    Color.black
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        headerSection
                        
                        foundationsSection
                            .zIndex(isDragging && selectedFromColumn == -1 ? 1 : 0)
                        
                        tableauSection
                            .zIndex(isDragging && (selectedFromColumn ?? -1) >= 0 ? 1 : 0)
                        
                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical)
                    
                    // This is the draggable copy that appears on top
                    draggedCardView
                }
                .disabled(showNewGameConfirmation || showNoMovesAlert)
                
                // --- Modals ---
                if showNewGameConfirmation {
                    ConfirmationSheetView(
                        title: "New Game?",
                        message: "Are you sure you want to leave your current game and start again?",
                        confirmButtonTitle: "Yes, start a new game",
                        cancelButtonTitle: "No, continue playing",
                        confirmAction: {
                            withAnimation {
                                gameState.newGame()
                                showNewGameConfirmation = false
                            }
                        },
                        cancelAction: {
                            withAnimation {
                                showNewGameConfirmation = false
                            }
                        }
                    )
                }
                
                if showNoMovesAlert {
                    ConfirmationSheetView(
                        title: "No More Moves",
                        message: "You've run out of moves.",
                        confirmButtonTitle: "New Game",
                        cancelButtonTitle: "OK",
                        confirmAction: {
                            withAnimation {
                                gameState.newGame()
                                showNoMovesAlert = false
                            }
                        },
                        cancelAction: {
                            withAnimation {
                                showNoMovesAlert = false
                            }
                        }
                    )
                }
            }
            .onAppear {
                calculateCardSize(geometry: geometry)
                gameState.newGame()
            }
            .onChange(of: geometry.size) { _, _ in
                calculateCardSize(geometry: geometry)
            }
            .onChange(of: gameState.gameWon) { _, isWon in
                if isWon {
                    HapticManager.shared.gameWin()
                }
            }
            .onChange(of: gameState.noMovesLeft) { _, newValue in
                if newValue {
                    // Use a slight delay to ensure other UI updates settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                           showNoMovesAlert = true
                        }
                    }
                }
            }
            .onPreferenceChange(FramePreferenceKey.self) { preferences in
                for pref in preferences {
                    switch pref.viewType {
                    case .foundation:
                        self.foundationFrames[pref.index] = pref.frame
                    case .tableau:
                        self.tableauFrames[pref.index] = pref.frame
                    }
                }
            }
        }
    }
    
    private func calculateCardSize(geometry: GeometryProxy) {
        // Calculate available width after padding
        let availableWidth = geometry.size.width - (horizontalPadding * 2)
        
        // Calculate card width based on 7 columns and spacing
        let totalSpacing = columnSpacing * 6 // 6 gaps between 7 columns
        cardWidth = (availableWidth - totalSpacing) / 7
        
        // Maintain aspect ratio
        cardHeight = cardWidth * cardAspectRatio
        
        // Cap the size for very large screens
        if cardWidth > 80 {
            cardWidth = 80
            cardHeight = cardWidth * cardAspectRatio
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Moves: \(gameState.moves)")
                    .font(.callout)
                    .foregroundColor(.gray)
                Text("Score: \(gameState.score)")
                    .font(.callout)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Button("New Game") {
                    withAnimation {
                        showNewGameConfirmation = true
                    }
                }
                .font(.callout)
                .foregroundColor(.white)
            }
        }
    }
    
    private var foundationsSection: some View {
        HStack {
            HStack(spacing: columnSpacing) {
                ForEach(0..<4, id: \.self) { index in
                    ZStack {
                        EmptyCardSlot(width: cardWidth, height: cardHeight)
                        
                        if let topCard = gameState.foundations[index].last {
                            CardView(card: topCard, width: cardWidth, height: cardHeight)
                        }
                    }
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: FramePreferenceKey.self, value: [FramePreferenceData(viewType: .foundation, index: index, frame: geometry.frame(in: .global))])
                    })
                }
            }
            
            Spacer()
            
            HStack(spacing: columnSpacing) {
                // Waste pile (now on left)
                ZStack(alignment: .leading) {
                    // Show up to 3 cards with overlap
                    ForEach(Array(gameState.waste.suffix(3).enumerated()), id: \.element.id) { index, card in
                        
                        let isBeingDragged = selectedCard?.id == card.id
                        
                        CardView(card: card, width: cardWidth, height: cardHeight)
                            .offset(x: CGFloat(index) * 25) // Increased overlap spacing from 15 to 25
                            .zIndex(Double(index))
                            .scaleEffect(isBeingDragged ? 1.05 : 1.0)
                            .opacity(isBeingDragged && isDragging ? 0 : 1)
                            .if(index == gameState.waste.suffix(3).count - 1) { view in
                                view.gesture(
                                    DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                        .onChanged { value in
                                            if !isDragging {
                                                selectCard(card: card, fromColumn: -1, cardIndex: nil)
                                                isDragging = true
                                                // Calculate the offset from grab point to card center
                                                // The card's position represents its center, so we need to offset by half the card size
                                                let grabOffset = CGSize(width: cardWidth/2, height: cardHeight/2)
                                                dragInitialOffset = grabOffset
                                                dragStartPosition = CGPoint(x: value.startLocation.x - grabOffset.width, y: value.startLocation.y - grabOffset.height)
                                            }
                                            dragOffset = value.translation
                                        }
                                        .onEnded(onDragEnded)
                                )
                            }
                    }
                }
                .frame(width: cardWidth + 50, alignment: .leading) // Increased frame width from 30 to 50
                
                // Stock pile (deck - now on right)
                Button(action: {
                    HapticManager.shared.cardFlip()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gameState.drawFromStock()
                    }
                }) {
                    ZStack {
                        EmptyCardSlot(width: cardWidth, height: cardHeight)
                        
                        if let topCard = gameState.stock.last {
                            CardView(card: topCard, width: cardWidth, height: cardHeight)
                        }
                    }
                }
                .disabled(gameState.stock.isEmpty && gameState.waste.isEmpty)
            }
        }
    }
    
    private var tableauSection: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            ForEach(0..<7, id: \.self) { columnIndex in
                tableauColumn(columnIndex: columnIndex)
            }
        }
    }
    
    private func tableauColumn(columnIndex: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(gameState.tableau[columnIndex].enumerated()), id: \.element.id) { cardIndex, card in
                
                let isPartOfDraggedStack = selectedFromColumn == columnIndex && selectedCardIndex != nil && cardIndex >= selectedCardIndex!
                
                // Calculate the offset based on all cards above this one
                let offset = calculateCardOffset(columnIndex: columnIndex, cardIndex: cardIndex)
                
                CardView(card: card, width: cardWidth, height: cardHeight)
                    .zIndex(Double(cardIndex))
                    .scaleEffect(isPartOfDraggedStack ? 1.05 : 1.0)
                    .opacity(isPartOfDraggedStack && isDragging ? 0 : 1)
                    .offset(y: offset)
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { value in
                                if card.isFaceUp && canStartDrag(card: card, columnIndex: columnIndex, cardIndex: cardIndex) && !isDragging {
                                    selectCard(card: card, fromColumn: columnIndex, cardIndex: cardIndex)
                                    isDragging = true
                                    // Calculate the offset from grab point to card center
                                    // For tableau cards, we need to account for the stack height
                                    let stackCount = gameState.tableau[columnIndex].count - (cardIndex)
                                    let stackHeight = cardHeight + (CGFloat(stackCount - 1) * (cardHeight * 0.2))
                                    let grabOffset = CGSize(width: cardWidth/2, height: stackHeight/2)
                                    dragInitialOffset = grabOffset
                                    dragStartPosition = CGPoint(x: value.startLocation.x - grabOffset.width, y: value.startLocation.y - grabOffset.height)
                                }
                                if isDragging {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded(onDragEnded)
                    )
                    .animation(.easeInOut(duration: 0.2), value: gameState.tableau[columnIndex].count)
            }
            
            if gameState.tableau[columnIndex].isEmpty {
                EmptyCardSlot(width: cardWidth, height: cardHeight)
                    .opacity(0.5)
            }
        }
        .frame(width: cardWidth)
        .background(GeometryReader { geometry in
            Color.clear.preference(key: FramePreferenceKey.self, value: [FramePreferenceData(viewType: .tableau, index: columnIndex, frame: geometry.frame(in: .global))])
        })
    }
    
    private func calculateCardOffset(columnIndex: Int, cardIndex: Int) -> CGFloat {
        guard cardIndex > 0 else { return 0 }
        
        let cards = gameState.tableau[columnIndex]
        var totalOffset: CGFloat = 0
        
        for i in 0..<cardIndex {
            let card = cards[i]
            let spacing = card.isFaceUp ? cardHeight * 0.55 : cardHeight * 0.8
            totalOffset += spacing
        }
        
        return -totalOffset
    }
    
    @ViewBuilder
    private var draggedCardView: some View {
        if let selectedCard = selectedCard {
            let position = CGPoint(x: dragStartPosition.x + dragOffset.width, y: dragStartPosition.y + dragOffset.height)
            
            if selectedFromColumn == -1 {
                // Dragging from waste
                CardView(card: selectedCard, width: cardWidth, height: cardHeight)
                    .scaleEffect(1.05)
                    .position(position)
            } else if let fromIndex = selectedCardIndex, let fromColumn = selectedFromColumn {
                // Dragging from tableau
                VStack(spacing: -cardHeight * 0.8) {
                    ForEach(Array(gameState.tableau[fromColumn].suffix(from: fromIndex)), id: \.id) { card in
                        CardView(card: card, width: cardWidth, height: cardHeight)
                    }
                }
                .scaleEffect(1.05)
                .position(position)
            }
        }
    }
    
    private func onDragEnded(value: DragGesture.Value) {
        let dropLocation = value.location
        
        // Check foundation drop with expanded drop zone
        if let card = selectedCard {
            for (index, frame) in foundationFrames.enumerated() {
                let expandedFrame = frame.insetBy(dx: -20, dy: -20) // Make drop zone 20px larger
                if expandedFrame.contains(dropLocation) {
                    if tryMoveToFoundation(selectedCard: card, foundationIndex: index) {
                        // Success
                    }
                    clearSelection()
                    return
                }
            }
            
            // Check tableau drop with expanded drop zone
            for (index, frame) in tableauFrames.enumerated() {
                let expandedFrame = frame.insetBy(dx: -20, dy: -20) // Make drop zone 20px larger
                if expandedFrame.contains(dropLocation) {
                    if tryMoveToTableau(selectedCard: card, columnIndex: index) {
                        // Success
                    }
                    clearSelection()
                    return
                }
            }
        }
        
        // If no target was hit, just snap back
        clearSelection()
    }
    
    private func selectCard(card: Card, fromColumn: Int, cardIndex: Int?) {
        HapticManager.shared.cardPickup()
        selectedCard = card
        selectedFromColumn = fromColumn
        selectedCardIndex = cardIndex
    }
    
    private func canStartDrag(card: Card, columnIndex: Int, cardIndex: Int) -> Bool {
        guard card.isFaceUp else { return false }
        
        let cardsInColumn = gameState.tableau[columnIndex]
        guard cardIndex < cardsInColumn.count else { return false }
        
        for i in cardIndex..<cardsInColumn.count - 1 {
            let current = cardsInColumn[i]
            let next = cardsInColumn[i + 1]
            
            if next.rank.rawValue != current.rank.rawValue - 1 || next.color == current.color {
                return false
            }
        }
        
        return true
    }
    
    private func tryMoveToTableau(selectedCard: Card, columnIndex: Int) -> Bool {
        guard let fromColumn = selectedFromColumn else { return false }
        
        let targetColumn = gameState.tableau[columnIndex]
        let targetCard = targetColumn.last
        
        if gameState.canMoveCard(from: selectedCard, to: targetCard) {
            HapticManager.shared.cardMove()
            withAnimation(.easeInOut(duration: 0.2)) {
                if fromColumn == -1 {
                    // Moving from waste pile
                    if !gameState.waste.isEmpty {
                        gameState.waste.removeLast()
                        gameState.tableau[columnIndex].append(selectedCard)
                    }
                } else {
                    // Moving from tableau
                    if let fromIndex = selectedCardIndex {
                        gameState.moveCards(from: fromColumn, cardIndex: fromIndex, to:columnIndex)
                    }
                }
                gameState.moves += 1
            }
            
            return true
        }
        
        HapticManager.shared.invalidMove()
        return false
    }
    
    private func tryMoveToFoundation(selectedCard: Card, foundationIndex: Int) -> Bool {
        guard let fromColumn = selectedFromColumn else { return false }
        
        // For aces, try to place in any available foundation slot, preferring the targeted one
        var targetFoundationIndex = foundationIndex
        if selectedCard.rank == .ace && !gameState.foundations[foundationIndex].isEmpty {
            if let availableIndex = gameState.findAvailableFoundationForAce(card: selectedCard) {
                targetFoundationIndex = availableIndex
            }
        }
        
        if gameState.canMoveToFoundation(card: selectedCard, foundationIndex: targetFoundationIndex) {
            HapticManager.shared.cardMove()
            withAnimation(.easeInOut(duration: 0.2)) {
                if fromColumn == -1 {
                    // Moving from waste pile
                    if !gameState.waste.isEmpty {
                        gameState.waste.removeLast()
                    }
                } else {
                    // Moving from tableau
                    if let fromIndex = selectedCardIndex {
                        gameState.tableau[fromColumn].removeLast(gameState.tableau[fromColumn].count - fromIndex)
                        // Flip the next card if needed
                        if let lastCard = gameState.tableau[fromColumn].last, !lastCard.isFaceUp {
                            let faceUpCard = Card(suit: lastCard.suit, rank: lastCard.rank, isFaceUp: true)
                            gameState.tableau[fromColumn][gameState.tableau[fromColumn].count - 1] = faceUpCard
                            gameState.score += 5
                            HapticManager.shared.cardFlip()
                        }
                    }
                }
                
                gameState.moveToFoundation(card: selectedCard, foundationIndex: targetFoundationIndex)
            }
            
            return true
        }
        
        HapticManager.shared.invalidMove()
        return false
    }
    
    private func clearSelection() {
        isDragging = false
        dragOffset = .zero
        dragStartPosition = .zero
        dragInitialOffset = .zero
        selectedCard = nil
        selectedFromColumn = nil
        selectedCardIndex = nil
    }
    
}

#Preview {
    GameView()
}
