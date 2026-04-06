import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab: Tab = .transactions
    @State private var showingFileImporter = false
    @State private var showingFileExporter = false
    @State private var showingSetupSheet = false
    
    enum Tab: String, CaseIterable {
        case transactions = "거래내역"
        case accounts = "계좌관리"
        case statistics = "통계"
    }
    
    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            TransactionListView()
                .tabItem {
                    Label("거래내역", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.transactions)
            
            AccountListView()
                .tabItem {
                    Label("계좌관리", systemImage: "banknote")
                }
                .tag(Tab.accounts)
            
            StatisticsView()
                .tabItem {
                    Label("통계", systemImage: "chart.bar")
                }
                .tag(Tab.statistics)
            
            SettingsView(showingFileImporter: $showingFileImporter, showingFileExporter: $showingFileExporter)
                .tabItem {
                    Label("설정", systemImage: "gear")
                }
                .tag(Tab.transactions)
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.json]) { result in
            handleFileImport(result)
        }
        .fileExporter(isPresented: $showingFileExporter, document: MoneyFlowDocument(data: dataManager.appData), contentType: .json, defaultFilename: "MoneyFlowData") { result in
            handleFileExport(result)
        }
        .onAppear {
            checkFirstLaunch()
        }
        .sheet(isPresented: $showingSetupSheet) {
            SetupSheetView(showingFileImporter: $showingFileImporter, showingFileExporter: $showingFileExporter)
        }
        #else
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: iconFor(tab: tab))
                    .tag(tab)
            }
            .navigationTitle("MoneyFlow")
            .listStyle(.sidebar)
            
            Divider()
            
            VStack(spacing: 12) {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("파일 열기", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button {
                    showingFileExporter = true
                } label: {
                    Label("다른 이름으로 저장", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let url = dataManager.currentFileURL {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding()
            .buttonStyle(.plain)
        } detail: {
            switch selectedTab {
            case .transactions:
                TransactionListView()
            case .accounts:
                AccountListView()
            case .statistics:
                StatisticsView()
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.json]) { result in
            handleFileImport(result)
        }
        .fileExporter(isPresented: $showingFileExporter, document: MoneyFlowDocument(data: dataManager.appData), contentType: .json, defaultFilename: "MoneyFlowData") { result in
            handleFileExport(result)
        }
        .onAppear {
            checkFirstLaunch()
        }
        .sheet(isPresented: $showingSetupSheet) {
            SetupSheetView(showingFileImporter: $showingFileImporter, showingFileExporter: $showingFileExporter)
        }
        #endif
    }
    
    private func iconFor(tab: Tab) -> String {
        switch tab {
        case .transactions: return "list.bullet.rectangle"
        case .accounts: return "banknote"
        case .statistics: return "chart.bar"
        }
    }
    
    private func checkFirstLaunch() {
        // 저장된 북마크에서 파일 로드 시도
        if !dataManager.loadFromBookmark() {
            // 첫 실행이면 설정 시트 표시
            if dataManager.currentFileURL == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingSetupSheet = true
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            dataManager.loadFromFile(url: url)
            showingSetupSheet = false
        case .failure(let error):
            dataManager.errorMessage = "파일 열기 실패: \(error.localizedDescription)"
        }
    }
    
    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            dataManager.currentFileURL = url
            dataManager.hasUnsavedChanges = false
        case .failure(let error):
            dataManager.errorMessage = "파일 저장 실패: \(error.localizedDescription)"
        }
    }
}

// MARK: - MoneyFlow Document (for FileExporter)
struct MoneyFlowDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: AppData
    
    init(data: AppData) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        data = try decoder.decode(AppData.self, from: fileData)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(data)
        return FileWrapper(regularFileWithContents: jsonData)
    }
}

// MARK: - Setup Sheet
struct SetupSheetView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @Binding var showingFileImporter: Bool
    @Binding var showingFileExporter: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "icloud")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("iCloud Drive 동기화 설정")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("맥북과 아이폰에서 데이터를 동기화하려면\niCloud Drive에 데이터 파일을 저장하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingFileImporter = true
                        }
                    } label: {
                        Label("기존 파일 열기", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingFileExporter = true
                        }
                    } label: {
                        Label("새 파일로 저장", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("나중에 하기")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 동기화 방법")
                        .font(.headline)
                    
                    Text("1. '새 파일로 저장' 선택\n2. iCloud Drive 폴더 선택\n3. 다른 기기에서 '기존 파일 열기'로 같은 파일 선택")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("시작하기")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Settings View (iOS)
struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var showingFileImporter: Bool
    @Binding var showingFileExporter: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("데이터 파일") {
                    if let url = dataManager.currentFileURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("현재 파일")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                        }
                    } else {
                        Text("파일이 선택되지 않음")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("파일 열기", systemImage: "folder")
                    }
                    
                    Button {
                        showingFileExporter = true
                    } label: {
                        Label("다른 이름으로 저장", systemImage: "square.and.arrow.down")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iCloud Drive 동기화 방법")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("1. '다른 이름으로 저장'을 눌러 iCloud Drive에 저장\n2. 다른 기기에서 '파일 열기'로 같은 파일 선택\n3. 양쪽 기기에서 같은 파일을 사용하면 자동 동기화")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("도움말")
                }
                
                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("마지막 업데이트")
                        Spacer()
                        Text(dataManager.appData.lastUpdated.dateString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("설정")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
