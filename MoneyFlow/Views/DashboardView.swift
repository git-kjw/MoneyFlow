import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showAllTime: Bool = true
    
    private var availableYears: [Int] {
        let years = Set(dataManager.appData.transactions.map { $0.date.year })
        let currentYear = Calendar.current.component(.year, from: Date())
        let allYears = years.union([currentYear])
        return Array(allYears).sorted(by: >)
    }
    
    private var filteredTransactions: [Transaction] {
        if showAllTime {
            return dataManager.appData.transactions
        } else {
            return dataManager.appData.transactions.filter { $0.date.year == selectedYear }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 날짜 필터
                dateFilterSection
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 전체 요약
                        totalSummaryCard
                        
                        // 계좌 카드들
                        accountCardsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("대시보드")
            .background(Color.systemBackground)
        }
    }
    
    // MARK: - Total Summary
    private var totalSummaryCard: some View {
        let totalDeposit = filteredTransactions.filter { $0.type == .deposit }.reduce(0) { $0 + $1.amount }
        let totalWithdrawal = filteredTransactions.filter { $0.type == .withdrawal }.reduce(0) { $0 + $1.amount }
        let netAmount = totalDeposit - totalWithdrawal
        
        return VStack(spacing: 16) {
            HStack {
                Text(showAllTime ? "전체 자산" : "\(selectedYear)년 자산")
                    .font(.headline)
                Spacer()
            }
            
            Text(netAmount.currencyFormatted)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(netAmount >= 0 ? Color.depositColor : Color.withdrawalColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Color.depositColor)
                        Text("총 입금")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(totalDeposit.currencyFormatted)
                        .font(.headline)
                        .foregroundStyle(Color.depositColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.withdrawalColor)
                        Text("총 출금")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(totalWithdrawal.currencyFormatted)
                        .font(.headline)
                        .foregroundStyle(Color.withdrawalColor)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Account Cards
    private var accountCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("계좌별 현황")
                .font(.headline)
            
            ForEach(dataManager.appData.accounts.filter { $0.isActive }) { account in
                AccountDashboardCard(
                    account: account, 
                    filteredTransactions: filteredTransactions
                )
            }
        }
    }
}

// MARK: - Account Dashboard Card
struct AccountDashboardCard: View {
    @EnvironmentObject var dataManager: DataManager
    let account: Account
    let filteredTransactions: [Transaction]
    
    private var stats: AccountStatistics {
        AccountStatistics(account: account, transactions: filteredTransactions)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.accountColor(for: account))
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.broker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("순입금")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stats.netAmount.currencyFormatted)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.accountColor(for: account))
                }
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(Color.depositColor)
                    Text(stats.totalDeposit.currencyFormatted)
                        .font(.subheadline)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(Color.withdrawalColor)
                    Text(stats.totalWithdrawal.currencyFormatted)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .foregroundStyle(.secondary)
            
            if let limit = account.yearlyLimit {
                Divider()
                
                let progress = Double(stats.yearlyDeposit) / Double(limit)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("올해 납입")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stats.yearlyDeposit.currencyFormatted)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress <= 1.0 ? Color.accountColor(for: account) : .red)
                        .frame(height: 8)
                    
                    HStack {
                        Text("목표 \(limit.currencyFormatted)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if (stats.remainingLimit ?? 0) > 0 {
                            Text("목표까지 \((stats.remainingLimit ?? 0).currencyFormatted)")
                                .font(.caption2)
                                .foregroundStyle(Color.accountColor(for: account))
                                .fontWeight(.medium)
                        } else {
                            Text("목표 달성!")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension DashboardView {
    // MARK: - Date Filter Section
    private var dateFilterSection: some View {
        VStack(spacing: 12) {
            // 전체/연도별 토글
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllTime = true
                    }
                } label: {
                    Text("전체")
                        .font(.subheadline)
                        .fontWeight(showAllTime ? .bold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(showAllTime ? Color.accentColor : Color.secondary.opacity(0.1))
                        .foregroundStyle(showAllTime ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllTime = false
                    }
                } label: {
                    Text("연도별")
                        .font(.subheadline)
                        .fontWeight(!showAllTime ? .bold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(!showAllTime ? Color.accentColor : Color.secondary.opacity(0.1))
                        .foregroundStyle(!showAllTime ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // 연도 선택 (연도별 모드일 때만)
            if !showAllTime {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableYears, id: \.self) { year in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedYear = year
                                }
                            } label: {
                                Text("\(year)")
                                    .font(.subheadline)
                                    .fontWeight(selectedYear == year ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedYear == year ? Color.accentColor : Color.secondary.opacity(0.1))
                                    .foregroundStyle(selectedYear == year ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical)
        .background(Color.systemBackground)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
}
