import SwiftUI

struct QuickEntryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAccount: Account?
    @State private var amount: String = ""
    @State private var transactionType: TransactionType = .deposit
    @State private var date = Date()
    @State private var memo: String = ""
    @State private var showingMemoField = false
    
    private var activeAccounts: [Account] {
        dataManager.appData.accounts.filter { $0.isActive }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if selectedAccount == nil {
                    accountSelectionView
                } else {
                    amountInputView
                }
            }
            .navigationTitle("빠른 입력")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                if selectedAccount != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            saveTransaction()
                        }
                        .disabled(amount.isEmpty || Int(amount) == nil)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Account Selection
    private var accountSelectionView: some View {
        VStack(spacing: 16) {
            Text("입금/출금할 계좌를 선택하세요")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 24)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(activeAccounts) { account in
                        AccountQuickButton(account: account) {
                            selectedAccount = account
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Amount Input
    private var amountInputView: some View {
        VStack(spacing: 20) {
            // 선택된 계좌 표시
            if let account = selectedAccount {
                HStack {
                    Circle()
                        .fill(Color.accountColor(for: account))
                        .frame(width: 12, height: 12)
                    
                    Text(account.displayName)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        selectedAccount = nil
                        amount = ""
                    } label: {
                        Text("변경")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top)
            }
            
            // 입금/출금 토글
            Picker("유형", selection: $transactionType) {
                ForEach(TransactionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // 금액 표시
            VStack(spacing: 8) {
                Text(transactionType == .deposit ? "입금" : "출금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(formattedAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(transactionType == .deposit ? Color.depositColor : Color.withdrawalColor)
                    .frame(height: 60)
            }
            .padding()
            
            // 숫자 패드
            numberPadView
            
            // 날짜 및 메모
            VStack(spacing: 12) {
                DatePicker("날짜", selection: $date, displayedComponents: .date)
                
                if showingMemoField {
                    TextField("메모 (선택사항)", text: $memo)
                        #if os(iOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                } else {
                    Button {
                        showingMemoField = true
                    } label: {
                        HStack {
                            Image(systemName: "note.text")
                            Text("메모 추가")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Number Pad
    private var numberPadView: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(1..<4) { col in
                        let number = row * 3 + col
                        NumberButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                NumberButton(number: "000") {
                    appendNumber("000")
                }
                
                NumberButton(number: "0") {
                    appendNumber("0")
                }
                
                NumberButton(number: "⌫", isDelete: true) {
                    deleteNumber()
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var formattedAmount: String {
        if amount.isEmpty {
            return "0원"
        }
        if let value = Int(amount) {
            return "\(value.currencyFormatted)"
        }
        return "0원"
    }
    
    // MARK: - Actions
    private func appendNumber(_ number: String) {
        amount += number
    }
    
    private func deleteNumber() {
        if !amount.isEmpty {
            amount.removeLast()
        }
    }
    
    private func saveTransaction() {
        guard let account = selectedAccount,
              let amountValue = Int(amount),
              amountValue > 0 else {
            return
        }
        
        let transaction = Transaction(
            accountId: account.id,
            amount: amountValue,
            type: transactionType,
            date: date,
            memo: memo.isEmpty ? nil : memo
        )
        
        dataManager.addTransaction(transaction)
        dismiss()
    }
}

// MARK: - Account Quick Button
struct AccountQuickButton: View {
    let account: Account
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(Color.accountColor(for: account))
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.broker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Number Button
struct NumberButton: View {
    let number: String
    var isDelete: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(isDelete ? .red : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickEntryView()
        .environmentObject(DataManager())
}
