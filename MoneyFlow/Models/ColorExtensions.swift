import SwiftUI

// MARK: - Account Color Enum
enum AccountColor: String, CaseIterable, Codable {
    case blue = "blue"
    case purple = "purple"
    case orange = "orange"
    case pink = "pink"
    case teal = "teal"
    case green = "green"
    case red = "red"
    case indigo = "indigo"
    case mint = "mint"
    case cyan = "cyan"
    case brown = "brown"
    case yellow = "yellow"
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .pink: return .pink
        case .teal: return .teal
        case .green: return .green
        case .red: return .red
        case .indigo: return .indigo
        case .mint: return .mint
        case .cyan: return .cyan
        case .brown: return .brown
        case .yellow: return .yellow
        }
    }
    
    var displayName: String {
        switch self {
        case .blue: return "파랑"
        case .purple: return "보라"
        case .orange: return "주황"
        case .pink: return "분홍"
        case .teal: return "청록"
        case .green: return "초록"
        case .red: return "빨강"
        case .indigo: return "남색"
        case .mint: return "민트"
        case .cyan: return "하늘"
        case .brown: return "갈색"
        case .yellow: return "노랑"
        }
    }
    
    // 다음 사용 가능한 색상 (이미 사용된 색상 제외)
    static func nextAvailableColor(usedColors: [String]) -> AccountColor {
        let used = Set(usedColors.compactMap { AccountColor(rawValue: $0) })
        return AccountColor.allCases.first { !used.contains($0) } ?? .blue
    }
}

extension Color {
    static var systemBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    // 계좌 색상 (Account 모델에서 가져옴)
    static func accountColor(for account: Account) -> Color {
        account.color.color
    }
    
    // 입금/출금 색상
    static var depositColor: Color { .green }
    static var withdrawalColor: Color { .red }
}
