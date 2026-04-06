import SwiftUI

struct AccountEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let editAccount: Account?
    
    @State private var name: String = ""
    @State private var broker: String = ""
    @State private var hasYearlyLimit: Bool = false
    @State private var yearlyLimit: String = ""
    @State private var selectedColor: AccountColor = .blue
    @State private var isActive: Bool = true
    
    init(editAccount: Account? = nil) {
        self.editAccount = editAccount
    }
    
    private var isEditing: Bool {
        editAccount != nil
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !broker.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // 자주 사용하는 증권사 목록
    private let commonBrokers = ["나무", "한투", "삼성", "미래에셋", "NH투자", "키움", "토스", "카카오페이"]
    
    var body: some View {
        NavigationStack {
            Form {
                // 기본 정보
                Section("기본 정보") {
                    TextField("계좌명", text: $name)
                        .textContentType(.name)
                    
                    TextField("증권사", text: $broker)
                    
                    // 증권사 빠른 선택
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonBrokers, id: \.self) { brokerName in
                                Button {
                                    broker = brokerName
                                } label: {
                                    Text(brokerName)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(broker == brokerName ? Color.accentColor : Color.accentColor.opacity(0.1))
                                        .foregroundStyle(broker == brokerName ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // 납입 한도
                Section {
                    Toggle("연간 목표 설정", isOn: $hasYearlyLimit)
                    
                    if hasYearlyLimit {
                        HStack {
                            TextField("목표 금액", text: $yearlyLimit)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                            Text("원")
                                .foregroundStyle(.secondary)
                        }
                        
                        // 자주 사용하는 목표액
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([9000000, 18000000, 20000000, 40000000], id: \.self) { limit in
                                    Button {
                                        yearlyLimit = "\(limit)"
                                    } label: {
                                        Text(limit.formatted)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Text("연금저축: 연 1,800만원\nIRP: 연 900만원\nISA: 연 2,000만원")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("납입 한도")
                } footer: {
                    Text("연금저축, IRP, ISA 등 납입 한도가 있는 계좌에 설정하세요.")
                }
                
                // 색상 선택
                Section("계좌 색상") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(AccountColor.allCases, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                    
                                    Text(color.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(selectedColor == color ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 활성 상태
                Section {
                    Toggle("계좌 활성화", isOn: $isActive)
                } footer: {
                    Text("비활성화된 계좌는 거래 추가 시 선택할 수 없습니다.")
                }
                
                // 삭제 버튼 (편집 모드)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let account = editAccount {
                                dataManager.deleteAccount(account)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("계좌 삭제")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "계좌 수정" : "계좌 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") {
                        saveAccount()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let account = editAccount {
                    name = account.name
                    broker = account.broker
                    hasYearlyLimit = account.yearlyLimit != nil
                    yearlyLimit = account.yearlyLimit.map { "\($0)" } ?? ""
                    selectedColor = account.color
                    isActive = account.isActive
                } else {
                    // 새 계좌 추가 시 사용되지 않은 색상 자동 선택
                    let usedColors = dataManager.appData.accounts.map { $0.colorName }
                    selectedColor = AccountColor.nextAvailableColor(usedColors: usedColors)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func saveAccount() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBroker = broker.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty, !trimmedBroker.isEmpty else { return }
        
        let limit: Int? = hasYearlyLimit ? Int(yearlyLimit) : nil
        
        if let existingAccount = editAccount {
            var updated = existingAccount
            updated.name = trimmedName
            updated.broker = trimmedBroker
            updated.yearlyLimit = limit
            updated.colorName = selectedColor.rawValue
            updated.isActive = isActive
            dataManager.updateAccount(updated)
        } else {
            let account = Account(
                name: trimmedName,
                broker: trimmedBroker,
                yearlyLimit: limit,
                colorName: selectedColor.rawValue,
                isActive: isActive
            )
            dataManager.addAccount(account)
        }
        
        dismiss()
    }
}

#Preview {
    AccountEditView()
        .environmentObject(DataManager())
}
