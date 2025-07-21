import SwiftUI

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameStats = GameStats.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("Statistics")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Your Performance")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }

                    VStack(spacing: 30) {
                        VStack(spacing: 15) {
                            HStack {
                                Text("Games Won")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameStats.gamesWon)")
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Text("Total Moves")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameStats.totalMoves)")
                                    .foregroundColor(.gray)
                            }

                            if gameStats.bestMoves > 0 {
                                HStack {
                                    Text("Best Game")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(gameStats.bestMoves) moves")
                                        .foregroundColor(.gray)
                                }
                            }

                            HStack {
                                Text("Current Streak")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameStats.currentStreak)")
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Text("Longest Streak")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameStats.longestStreak)")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 40)
                    }

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    StatsView()
}
