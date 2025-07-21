import SwiftUI

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameStats = GameStats.shared
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Statistics")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Your Nintai Performance")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Game Stats
                        VStack(spacing: 15) {
                            StatCard(title: "Games Won", value: "\(gameStats.gamesWon)")
                            StatCard(title: "Total Moves", value: "\(gameStats.totalMoves)")
                            if gameStats.bestMoves > 0 {
                                StatCard(title: "Best Game (Fewest Moves)", value: "\(gameStats.bestMoves)")
                            }
                        }
                        
                        // Streak Stats
                        VStack(spacing: 15) {
                            StatCard(title: "Current Win Streak", value: "\(gameStats.currentStreak)")
                            StatCard(title: "Longest Win Streak", value: "\(gameStats.longestStreak)")
                        }
                        
                        Spacer(minLength: 50)
                        
                        // Reset button
                        Button(action: {
                            showingResetConfirmation = true
                        }) {
                            Text("Reset Statistics")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Reset Statistics", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                gameStats.resetStats()
            }
        } message: {
            Text("Are you sure you want to reset all statistics? This cannot be undone.")
        }
    }
}


#Preview {
    StatsView()
}