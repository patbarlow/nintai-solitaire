import SwiftUI

struct MenuView: View {
    @StateObject private var gameStats = GameStats.shared
    @State private var showingStats = false
    @State private var showingGame = false
    @State private var hasOngoingGame = false
    @State private var showNewGameConfirmation = false
    @State private var forceNewGame = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean black background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Nintai")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Solitaire")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    // Simple stats centered
                    HStack(spacing: 20) {
                        VStack {
                            Text("Best: \(gameStats.bestMoves > 0 ? "\(gameStats.bestMoves)" : "--")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack {
                            Text("Won: \(gameStats.gamesWon)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Menu buttons
                    VStack(spacing: 20) {
                        // New Game Button
                        Button(action: {
                            if hasOngoingGame {
                                showNewGameConfirmation = true
                            } else {
                                forceNewGame = true
                                showingGame = true
                            }
                        }) {
                            Text("New Game")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(25)
                        }
                        .padding(.horizontal, 40)
                        
                        // Continue Game Button (if available)
                        if hasOngoingGame {
                            Button(action: {
                                showingGame = true
                            }) {
                                Text("Continue Game")
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
                            .padding(.horizontal, 40)
                        }
                        
                        // Statistics Button
                        Button(action: {
                            showingStats = true
                        }) {
                            Text("Statistics")
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
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingStats) {
            StatsView()
        }
        .fullScreenCover(isPresented: $showingGame, onDismiss: {
            forceNewGame = false
            checkForOngoingGame()
        }) {
            if forceNewGame {
                GameView()
            } else if let savedGame = GameState.loadGameState() {
                GameView(savedGame: savedGame)
            } else {
                GameView()
            }
        }
        .onAppear {
            checkForOngoingGame()
        }
        .alert("New Game?", isPresented: $showNewGameConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Start New Game", role: .destructive) {
                if let savedGame = GameState.loadGameState() {
                    if !savedGame.gameWon {
                        gameStats.recordGameLoss(moves: savedGame.moves)
                    }
                }
                GameState().clearSavedGameState()
                forceNewGame = true
                showingGame = true
            }
        } message: {
            Text("Are you sure you want to start a new game? This will abandon any current game.")
        }
    }
    
    private func checkForOngoingGame() {
        hasOngoingGame = UserDefaults.standard.object(forKey: "savedGameState") != nil
    }
}

#Preview {
    MenuView()
}
