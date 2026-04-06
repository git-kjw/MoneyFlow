import SwiftUI

struct AccountListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var selectedAccount: Account?
    @State private var showingDeleteAlert = false
    @State private var accountToDelete: Account?
    
    var body: some View {
        NavigationStack {
            List {
                // 한도 있는 계좌 (연금저축, ISA, IRP 등)
                let limitAccounts = dataManager.appData.accounts.filter { $0.yearlyLimit != nil && $0.isActive }
                if !limitAccounts.isEmpty {
                    Section("납입 한도 계좌") {
                        ForEach(limitAccounts) { account in
                            AccountLimitRow(account: account)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAccount = account
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        accountToDelete = account
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                // 일반 계좌
                let normalAccounts = dataManager.appData.accounts.filter { $0.yearlyLimit == nil && $0.isActive }
                if !normalAccounts.isEmpty {
                    Section("일반 계좌") {
                        ForEach(normalAccounts) { account in
                            AccountRow(account: account)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAccount = account
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        accountToDelete = account
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                // 비활성 계좌
                let inactiveAccounts = dataManager.appData.accounts.filter { !$0.isActive }
                if !inactiveAccounts.isEmpty {
                    Section("비활성 계좌") {
                        ForEach(inactiveAccounts) { account in
                            AccountRow(account: account)
                                .opacity(0.6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAccount = account
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        accountToDelete = account
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("계좌 관리")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AccountEditView()
            }
            .sheet(item: $selectedAccount) { account in
                AccountEditView(editAccount: account)
            }
            .alert("계좌 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    if let account = accountToDelete {
                        dataManager.deleteAccount(account)
                    }
                }
            } message: {
                if let account = accountToDelete {
                    let transactionCount = dataManager.appData.transactions.filter { $0.accountId == account.id }.count
                    Text("\(account.displayName) 계좌를 삭제하시겠습니까?\n\(transactionCount)건의 거래내역도 함께 삭제됩니다.")
                }
            }
            .overlay {
                if dataManager.appData.accounts.isEmpty {
                    emptyStateView
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "banknote")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("계좌가 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddSheet = true
            } label: {
                Label("계좌 추가하기", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Account Row (Simple)
struct AccountRow: View {
    @EnvironmentObject var dataManager: DataManager
    let account: Account
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                Text(account.broker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            let stats = dataManager.getStatistics(for: account)
            VStack(alignment: .trailing, spacing: 4) {
                Text("총 입금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stats.totalDeposit.currencyFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Account Limit Row
struct AccountLimitRow: View {
    @EnvironmentObject var dataManager: DataManager
    let account: Account
    
    var body: some View {
        let stats = dataManager.getStatistics(for: account)
        let limit = account.yearlyLimit ?? 0
        let progress = limit > 0 ? Double(stats.yearlyDeposit) / Double(limit) : 0
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.broker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("남은 한도")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text((stats.remainingLimit ?? 0).currencyFormatted)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle((stats.remainingLimit ?? 0) > 0 ? .green : .red)
                }
            }
            
            // 프로그레스 바
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(progress, 1.0))
                    .tint(progress <= 1.0 ? .green : .red)
                
                HStack {
                    Text("\(stats.yearlyDeposit.formatted)원")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(limit.formatted)원")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AccountListView()
        .environmentObject(DataManager())
}
