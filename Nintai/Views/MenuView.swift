import SwiftUI

struct MenuView: View {
    @StateObject private var gameStats = GameStats.shared
    @State private var showingStats = false
    @State private var showingGame = false
    @State private var hasOngoingGame = false
    @State private var selectedTab = 0
    @State private var showNewGameConfirmation = false
    @State private var forceNewGame = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top section with title
                    HStack {
                        Text("Nintai")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Main content based on selected tab
                    if selectedTab == 0 {
                        // Game tab content
                        VStack(spacing: 20) {
                            // Resume/New Game card
                            Button(action: {
                                showingGame = true
                            }) {
                                VStack(spacing: 15) {
                                    // Simple card icons
                                    HStack(spacing: 10) {
                                        Image(systemName: "suit.diamond.fill")
                                            .foregroundColor(.red)
                                        Image(systemName: "suit.club.fill")
                                            .foregroundColor(.white)
                                        Image(systemName: "suit.heart.fill")
                                            .foregroundColor(.red)
                                        Image(systemName: "suit.spade.fill")
                                            .foregroundColor(.white)
                                    }
                                    .font(.title)
                                    
                                    Text(hasOngoingGame ? "Resume Game" : "New Game")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                                .padding(.horizontal, 20)
                                .background(Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                            
                            // New Game card (always visible)
                            Button(action: {
                                showNewGameConfirmation = true
                            }) {
                                VStack(spacing: 15) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                    
                                    Text("New Game")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                                .padding(.horizontal, 20)
                                .background(Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                        }
                    } else {
                        // Stats tab content
                        StatsTabView()
                    }
                    
                    Spacer()
                    
                    // Bottom navigation
                    HStack(spacing: 0) {
                        // Game tab
                        Button(action: {
                            selectedTab = 0
                        }) {
                            Image(systemName: "suit.club.fill")
                                .font(.largeTitle)
                                .foregroundColor(selectedTab == 0 ? .white : .gray)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Stats tab
                        Button(action: {
                            selectedTab = 1
                        }) {
                            Image(systemName: "person.fill")
                                .font(.largeTitle)
                                .foregroundColor(selectedTab == 1 ? .white : .gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 40)
                    .background(Color.black)
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
                // If there's an ongoing game, record it as abandoned (loss)
                if let savedGame = GameState.loadGameState() {
                    if !savedGame.gameWon {
                        gameStats.recordGameLoss(moves: savedGame.moves)
                        print("DEBUG: Recorded abandoned game as loss, moves: \(savedGame.moves), games played: \(gameStats.gamesPlayed)")
                    }
                }
                // Clear saved game and start fresh
                GameState().clearSavedGameState()
                forceNewGame = true
                showingGame = true
            }
        } message: {
            Text("Are you sure you want to start a new game? This will abandon any current game.")
        }
    }
    
    private func checkForOngoingGame() {
        // Check if there's a saved game state
        hasOngoingGame = UserDefaults.standard.object(forKey: "savedGameState") != nil
    }
}

struct StatsTabView: View {
    @StateObject private var gameStats = GameStats.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Game Stats
            VStack(spacing: 15) {
                StatCard(title: "Games Won", value: "\(gameStats.gamesWon)")
                StatCard(title: "Total Moves", value: "\(gameStats.totalMoves)")
                if gameStats.bestMoves > 0 {
                    StatCard(title: "Best Game", value: "\(gameStats.bestMoves) moves")
                }
            }
            
            // Streak Stats
            VStack(spacing: 15) {
                StatCard(title: "Current Streak", value: "\(gameStats.currentStreak)")
                StatCard(title: "Longest Streak", value: "\(gameStats.longestStreak)")
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    MenuView()
}
