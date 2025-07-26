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
    @StateObject private var gameState: GameState
    private let isNewGame: Bool
    @State private var dealtCards: [[Bool]] = []
    @State private var flippedCards: [[Bool]] = []
    @State private var showGameContent = false
    @State private var isDealing = false
    @State private var selectedCard: Card?
    @State private var selectedFromColumn: Int?
    @State private var selectedCardIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var dragInitialOffset: CGSize = .zero
    @State private var foundationFrames: [CGRect] = Array(repeating: .zero, count: 4)
    @State private var tableauFrames: [CGRect] = Array(repeating: .zero, count: 7)
    @Environment(\.presentationMode) var presentationMode
    
    // Confirmation States
    @State private var showQuitGameConfirmation = false
    @State private var showNoMovesAlert = false
    @State private var showWinAlert = false
    
    // Dynamic sizing based on screen width
    @State private var cardWidth: CGFloat = 45
    @State private var cardHeight: CGFloat = 63
    
    let cardAspectRatio: CGFloat = 63.0 / 45.0 // height / width
    let horizontalPadding: CGFloat = 5 // Padding on either side
    let columnSpacing: CGFloat = 8 // Space between columns
    
    init(savedGame: GameState? = nil) {
        let state = savedGame ?? GameState()
        _gameState = StateObject(wrappedValue: state)
        isNewGame = savedGame == nil
        if isNewGame {
            _dealtCards = State(initialValue: state.tableau.map { column in column.map { _ in false } })
            _flippedCards = State(initialValue: state.tableau.map { column in column.map { _ in false } })
            _showGameContent = State(initialValue: false)
            // ensure last cards start face down
            for column in 0..<state.tableau.count {
                if let lastIndex = state.tableau[column].indices.last {
                    state.tableau[column][lastIndex].isFaceUp = false
                }
            }
        } else {
            _dealtCards = State(initialValue: state.tableau.map { column in column.map { _ in true } })
            _flippedCards = State(initialValue: state.tableau.map { column in column.map { _ in true } })
            _showGameContent = State(initialValue: true)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack { // Outer ZStack for layering modals over the game
                ZStack { // Original ZStack for game content
                    Color.black
                        .ignoresSafeArea()
                        .onTapGesture {
                            if selectedCard != nil && !isDragging {
                                clearSelection()
                            }
                        }
                    
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
                .disabled(showQuitGameConfirmation || showNoMovesAlert || showWinAlert || isDealing)
                
                // --- Modals ---
                if showQuitGameConfirmation {
                    MinimalQuitModal(
                        onQuitToMenu: {
                            withAnimation {
                                gameState.clearSavedGameState()
                                showQuitGameConfirmation = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        },
                        onNewGame: {
                            withAnimation {
                                gameState.newGame()
                                showQuitGameConfirmation = false
                            }
                        },
                        onCancel: {
                            withAnimation {
                                showQuitGameConfirmation = false
                            }
                        }
                    )
                }
                
                if showNoMovesAlert {
                    MinimalConfirmationModal(
                        title: "No More Moves",
                        message: "You've run out of moves. Would you like to start a new game?",
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
                
                if showWinAlert {
                    MinimalWinModal(
                        moves: gameState.moves,
                        onNewGame: {
                            withAnimation {
                                gameState.newGame()
                                showWinAlert = false
                            }
                        },
                        onContinue: {
                            withAnimation {
                                showWinAlert = false
                            }
                        }
                    )
                }
            }
            .opacity(showGameContent ? 1 : 0)
            .onAppear {
                calculateCardSize(geometry: geometry)
                if isNewGame {
                    startDealAnimation()
                } else {
                    withAnimation(.easeIn(duration: 0.2)) {
                        showGameContent = true
                    }
                }
            }
            .onChange(of: geometry.size) { _, _ in
                calculateCardSize(geometry: geometry)
            }
            .onChange(of: gameState.gameWon) { _, isWon in
                if isWon {
                    HapticManager.shared.gameWin()
                    // Use a slight delay to ensure other UI updates settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showWinAlert = true
                        }
                    }
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
                    .fontWeight(.medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.2), lineWidth: 0.8)
                            }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showQuitGameConfirmation = true
                    }
                }) {
                    Text("Quit Game")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.red.opacity(0.2), lineWidth: 0.5)
                                }
                        }
                        .shadow(color: .red.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
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
                    .contentShape(Rectangle())
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: FramePreferenceKey.self, value: [FramePreferenceData(viewType: .foundation, index: index, frame: geometry.frame(in: .global))])
                    })
                    .onTapGesture {
                        if !isDragging, let card = selectedCard {
                            _ = tryMoveToFoundation(selectedCard: card, foundationIndex: index)
                            clearSelection()
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: columnSpacing) {
                // Waste pile (now on left)
                ZStack(alignment: .leading) {
                    // Show up to 3 cards with overlap
                    ForEach(Array(gameState.waste.suffix(3).enumerated()), id: \.element.id) { index, card in

                        let isBeingDragged = selectedCard?.id == card.id
                        let isSelected = !isDragging && selectedFromColumn == -1 && selectedCard?.id == card.id

                        CardView(card: card, width: cardWidth, height: cardHeight)
                            .offset(x: CGFloat(index) * 25)
                            .zIndex(Double(index))
                            .scaleEffect(isBeingDragged ? 1.05 : (isSelected ? 1.1 : 1.0))
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
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        if !isDragging {
                                            if selectedCard?.id == card.id && selectedFromColumn == -1 {
                                                clearSelection()
                                            } else {
                                                selectCard(card: card, fromColumn: -1, cardIndex: nil)
                                            }
                                        }
                                    }
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
                if dealtCards[columnIndex][cardIndex] {
                    let isPartOfDraggedStack = selectedFromColumn == columnIndex && selectedCardIndex != nil && cardIndex >= selectedCardIndex!
                    let isPartOfSelectedStack = !isDragging && isPartOfDraggedStack

                    // Calculate the offset based on all cards above this one
                    let offset = calculateCardOffset(columnIndex: columnIndex, cardIndex: cardIndex)

                    let displayCard: Card = isNewGame && !flippedCards[columnIndex][cardIndex] &&
                        cardIndex == gameState.tableau[columnIndex].count - 1
                        ? Card(suit: card.suit, rank: card.rank, isFaceUp: false)
                        : card
                 

                    CardView(card: displayCard, width: cardWidth, height: cardHeight)
                        .zIndex(Double(cardIndex))
                        .scaleEffect(isPartOfDraggedStack ? 1.05 : (isPartOfSelectedStack ? 1.1 : 1.0))
                        .opacity(isPartOfDraggedStack && isDragging ? 0 : 1)
                        .offset(y: offset)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                guard !isDragging else { return }

                                if let selected = selectedCard {
                                    if selectedFromColumn == columnIndex,
                                       let selectedIndex = selectedCardIndex,
                                       cardIndex >= selectedIndex {
                                        clearSelection()
                                    } else {
                                        _ = tryMoveToTableau(selectedCard: selected, columnIndex: columnIndex)
                                        clearSelection()
                                    }
                                } else if card.isFaceUp && canStartDrag(card: card, columnIndex: columnIndex, cardIndex: cardIndex) {
                                    selectCard(card: card, fromColumn: columnIndex, cardIndex: cardIndex)
                                }
                            }
                        )
                        .animation(.easeInOut(duration: 0.2), value: gameState.tableau[columnIndex].count)
                }
            }
            
            if gameState.tableau[columnIndex].isEmpty {
                EmptyCardSlot(width: cardWidth, height: cardHeight)
                    .opacity(0.5)
            }
        }
        .contentShape(Rectangle())
        .frame(width: cardWidth)
        .onTapGesture {
            if !isDragging, let selected = selectedCard {
                if selectedFromColumn == columnIndex {
                    clearSelection()
                } else {
                    _ = tryMoveToTableau(selectedCard: selected, columnIndex: columnIndex)
                    clearSelection()
                }
            }
        }
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
        if isDragging, let selectedCard = selectedCard {
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
                gameState.saveGameState()
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
                        if !gameState.tableau[fromColumn].isEmpty && !gameState.tableau[fromColumn].last!.isFaceUp {
                            gameState.tableau[fromColumn][gameState.tableau[fromColumn].count - 1].isFaceUp = true
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

    private func startDealAnimation() {
        isDealing = true
        withAnimation(.easeIn(duration: 0.2)) {
            showGameContent = true
        }
        var delay: Double = 0
        let step: Double = 0.08

        for column in 0..<dealtCards.count {
            for row in 0..<dealtCards[column].count {
                let isLast = row == dealtCards[column].count - 1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dealtCards[column][row] = true
                        HapticManager.shared.cardMove()
                    }
                    if isLast {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                flippedCards[column][row] = true
                                gameState.tableau[column][row].isFaceUp = true
                                HapticManager.shared.cardFlip()
                                if column == dealtCards.count - 1 {
                                    isDealing = false
                                }
                            }
                        }
                    }
                }
                delay += step
            }
        }
    }
    
}

struct MinimalQuitModal: View {
    let onQuitToMenu: () -> Void
    let onNewGame: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Simple black overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("Quit Game")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
//                    Text("Are you sure you'd like to quit?")
//                        .font(.title2)
//                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 20) {
                    // Quit to Main Menu - White button
                    Button(action: onQuitToMenu) {
                        Text("Quit to Main Menu")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                    }
                    
                    // Start New Game - Red outline
                    Button(action: onNewGame) {
                        Text("Start New Game")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                    }
                    
                    // Continue Playing - White outline
                    Button(action: onCancel) {
                        Text("Continue Playing")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

struct CleanGlassButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    }
            }
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            withAnimation(.easeOut(duration: 0.1).delay(0.1)) {
                isPressed = false
            }
        }
    }
}

struct MinimalConfirmationModal: View {
    let title: String
    let message: String
    let confirmButtonTitle: String
    let cancelButtonTitle: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture(perform: cancelAction)
            
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    Button(action: confirmAction) {
                        Text(confirmButtonTitle)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                    }
                    
                    Button(action: cancelAction) {
                        Text(cancelButtonTitle)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

struct MinimalWinModal: View {
    let moves: Int
    let onNewGame: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture(perform: onContinue)
            
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Congratulations!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("You won in \(moves) moves!")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 20) {
                    Button(action: onNewGame) {
                        Text("New Game")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                    }
                    
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    GameView()
}
