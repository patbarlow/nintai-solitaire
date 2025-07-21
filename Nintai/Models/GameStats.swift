import Foundation

@MainActor
class GameStats: ObservableObject {
    @Published var gamesPlayed: Int = 0
    @Published var gamesWon: Int = 0
    @Published var totalMoves: Int = 0
    @Published var bestMoves: Int = 0
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    
    static let shared = GameStats()
    
    private init() {
        loadStats()
    }
    
    var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(gamesWon) / Double(gamesPlayed) * 100
    }
    
    var averageMovesPerGame: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(totalMoves) / Double(gamesPlayed)
    }
    
    func recordGameStart() {
        gamesPlayed += 1
        print("DEBUG: recordGameStart called, games played now: \(gamesPlayed)")
        saveStats()
    }
    
    func recordGameWin(moves: Int) {
        gamesWon += 1
        totalMoves += moves
        currentStreak += 1
        
        if bestMoves == 0 || moves < bestMoves {
            bestMoves = moves
        }
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        saveStats()
    }
    
    func recordGameLoss(moves: Int) {
        totalMoves += moves
        currentStreak = 0
        print("DEBUG: recordGameLoss called, moves: \(moves), games played: \(gamesPlayed), total moves: \(totalMoves)")
        saveStats()
    }
    
    private func saveStats() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(gamesPlayed, forKey: "gamesPlayed")
        userDefaults.set(gamesWon, forKey: "gamesWon")
        userDefaults.set(totalMoves, forKey: "totalMoves")
        userDefaults.set(bestMoves, forKey: "bestMoves")
        userDefaults.set(currentStreak, forKey: "currentStreak")
        userDefaults.set(longestStreak, forKey: "longestStreak")
    }
    
    private func loadStats() {
        let userDefaults = UserDefaults.standard
        gamesPlayed = userDefaults.integer(forKey: "gamesPlayed")
        gamesWon = userDefaults.integer(forKey: "gamesWon")
        totalMoves = userDefaults.integer(forKey: "totalMoves")
        bestMoves = userDefaults.integer(forKey: "bestMoves")
        currentStreak = userDefaults.integer(forKey: "currentStreak")
        longestStreak = userDefaults.integer(forKey: "longestStreak")
    }
}
