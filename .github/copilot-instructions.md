# MoneyFlow Copilot 가이드

## 빠른 시작

MoneyFlow는 **macOS + iOS 유니버설 앱**으로, 은행 계좌 거래 내역과 투자 입금을 추적하고 iCloud Drive를 통해 기기 간 동기화할 수 있습니다.

### 빌드 및 실행

```bash
# Xcode에서 프로젝트 열기
open MoneyFlow.xcodeproj

# 터미널에서 macOS 빌드
xcodebuild -project MoneyFlow.xcodeproj -scheme MoneyFlow -destination 'platform=macOS' build

# 터미널에서 iOS 빌드
xcodebuild -project MoneyFlow.xcodeproj -scheme MoneyFlow -destination 'generic/platform=iOS' build
```

**Xcode에서**: ⌘R로 macOS 또는 연결된 iOS 기기에서 실행. 필요시 Signing & Capabilities에서 Team을 개인 Apple ID로 설정.

### 자동 테스트 및 린팅 없음
이 SwiftUI 앱은 자동화된 테스트 스위트나 린팅 도구가 없습니다. macOS와 iOS에서의 수동 테스트가 표준입니다.

---

## 아키텍처

### 전체 설계 개요

- **데이터 모델**: `Models/Models.swift`에서 `Account`와 `Transaction` 구조체를 `Codable`로 정의
- **지속성**: `DataManager` (앱의 단일 `@StateObject`)가 다음을 관리:
  - **주요 저장소**: iCloud Drive에 저장된 JSON 파일 (`MoneyFlowData.json`)
  - **백업**: 오프라인 액세스를 위한 UserDefaults
  - **파일 모니터링**: JSON 파일의 외부 변경을 감시하고 자동으로 새로고침
- **UI 계층**: SwiftUI 뷰를 기능별로 구성 (거래, 계좌, 통계)
- **크로스 플랫폼**: 조건부 컴파일(`#if os(macOS)`)로 플랫폼별 동작 구분

### 진입점

- **앱**: `MoneyFlowApp.swift` — 메인 앱 구조체, 환경을 통해 `DataManager` 주입
- **메인 UI**: `ContentView.swift` — 탭 네비게이션 (대시보드, 계좌, 거래, 통계)
- **데이터 소스**: `DataManager`는 `@StateObject`이며 `@EnvironmentObject`를 통해 앱 전체에 제공됨

### 주요 패턴

1. **AppData 래퍼**: 계좌 및 거래 배열을 포함하는 최상위 Codable 구조체
2. **커스텀 JSON UTType**: `MoneyFlowApp.swift`에서 `.moneyFlowData` 타입을 확장 (파일 선택기용)
3. **ISO8601 날짜**: 모든 날짜 인코딩/디코딩은 `.iso8601` 전략 사용
4. **역호환성**: `Account.init(from:)` 커스텀 디코딩으로 누락된 필드를 처리하고 레거시 데이터에 색상 자동 할당
5. **파일 보안 스코프**: `loadFromFile()`과 `saveToFile()`은 iCloud Drive 액세스를 위해 `startAccessingSecurityScopedResource()` 사용

---

## 주요 관례

### 명명 및 구성

- **파일**: CamelCase로 목적을 명확히 함 (예: `StatisticsView.swift`, `AddTransactionView.swift`)
- **폴더**: `Models/`, `Views/`, `Services/` — 기능 기반 구성
- **확장**: 유틸리티 확장은 `Models/Extensions.swift`와 `Models/ColorExtensions.swift`에 위치

### SwiftUI 패턴

- **상태 관리**: 뷰는 로컬 상태에 `@State`, `DataManager` 액세스에 `@EnvironmentObject` 사용
- **데이터 바인딩**: 모델의 계산된 속성 (예: `displayName`, `color`)을 뷰 친화적으로 포맷팅
- **차트**: 네이티브 `Charts` 프레임워크(iOS 16+, macOS 13+) 사용, Y축 커스텀 포매팅
- **Async/Await**: `DataManager.refreshData()`는 파일 I/O용 `async` 사용; 뷰는 `.task` 또는 `.refreshable`로 호출
- **모디파이어**: `.refreshable`은 ScrollView/List용 pull-to-refresh; `.onChange`는 실시간 입력 포매팅용

### 데이터 처리

- **Account.colorName**: "blue", "purple" 등의 `String`으로 저장, `Account.color` 계산된 속성을 통해 `Color`로 매핑
- **Transaction.type**: "deposit" 또는 "withdrawal" 문자열
- **금액**: `Int` (원 단위, 소수 없음)로 저장
- **날짜**: `Date`로 저장, 헬퍼 확장을 사용하여 표시용으로 포매팅

### 한글 지역화

- **숫자 포매팅**: `Double.chartFormatted` 확장이 큰 금액을 "만원"(만 원 단위) 또는 "억원"(백만 원 단위)으로 변환
- **UI 문자열**: 앱 전체에 한글로 하드코딩; Localizable.strings 파일 없음
- **용어**: "목표" (연간 한도), "순증감" (입금-출금 차이)

### 색상 시스템

`ColorExtensions.swift`는 계좌 색상을 다음과 같이 정의:
- `"blue"`, `"purple"`, `"orange"`, `"pink"`, `"teal"`
- `AccountColor.colorValue`를 통해 SwiftUI `Color` 객체로 매핑
- 역호환성을 위해 커스텀 `Account` 디코더에서 색상 할당

---

## 중요 구현 세부사항

### 파일 동기화

- JSON이 소스 오브 트루스이며, iCloud Drive가 기기 간 동기화를 자동으로 처리
- `DataManager`는 외부 변경(예: 다른 기기의 업데이트)을 감시
- 파일 변경 감지 시 자동으로 새로고침 (사용자 조치 필요 없음)
- JSON 파일과 UserDefaults 모두에 저장 (폴백용)

### Pull-to-Refresh

모든 주요 뷰(`DashboardView`, `TransactionListView`, `AccountListView`, `StatisticsView`)는 `.refreshable` 모디파이어를 통해 pull-to-refresh 지원. 이는 `dataManager.refreshData()`를 호출하여 파일에서 새로고침합니다.

### 입력 포매팅

`AddTransactionView` 포함 사항:
- 금액 입력 시 실시간 콤마 삽입 (`onChange` 모디파이어 사용)
- 3열 그리드의 빠른 금액 버튼 (1만원, 5만원, 10만원 등)
- 숫자만 입력 가능하도록 검증

### 통계 포매팅

- Y축 라벨은 자동으로 큰 숫자를 읽기 쉬운 단위로 변환 ("2.0E7" 대신 "2000만원")
- 연도는 콤마 없이 표시 ("2,026" 대신 "2026")
- 순증감은 색상 코딩으로 표시 (양수는 초록색, 음수는 빨간색)

---

## 일반적인 작업

### 새로운 거래 필드 추가

1. `Models/Models.swift`의 `Transaction` 구조체에 필드 추가
2. `Transaction.init()`과 커스텀 코딩 로직 업데이트
3. 필요시 `AppData.defaultData` 업데이트
4. 거래를 표시/편집하는 뷰 업데이트 (`AddTransactionView`, `TransactionListView`)
5. JSON 직렬화/역직렬화 테스트

### 새로운 계좌 한도 유형 추가

1. `Account` 구조체에 선택적 필드 추가 (기존 `yearlyLimit` 같은 형태)
2. 커스텀 디코더에서 누락된 필드를 우아하게 처리
3. 필요시 계산된 통계 로직 추가
4. 필요에 따라 `StatisticsView`에 표시

### 새 데이터를 위해 뷰 수정

- 뷰는 `@EnvironmentObject var dataManager: DataManager`를 사용해 데이터 액세스
- `dataManager.appData` 속성에 직접 또는 계산된 속성을 통해 바인딩
- 뷰 계층 아래로 데이터를 전달할 때 항상 `.environmentObject(dataManager)` 사용

---

## 알아두면 좋은 파일들

- **MoneyFlowApp.swift**: 앱 진입점, UTType 정의, 윈도우 스타일
- **ContentView.swift**: 탭 네비게이션 조직
- **DataManager.swift**: 모든 파일 I/O, 동기화 로직, 상태 관리
- **Models/Models.swift**: `Account`, `Transaction`, `AppData` 구조체
- **Models/Extensions.swift**: 유틸리티 함수, 숫자 포매팅용 `Double.chartFormatted`
- **Models/ColorExtensions.swift**: 계좌 색상 매핑
- **Views/**: 기능별 UI (대시보드, 통계, 계좌, 거래)
- **MoneyFlow.entitlements**: iCloud Drive 기능 + 샌드박스 설정
- **.gitignore**: 표준 Xcode/CocoaPods 패턴

---

## 디버깅 팁

- JSON 파일이 손상되면 UserDefaults (폴백 저장소) 확인
- 파일 모니터가 빠른 변경을 놓칠 수 있으니, 필요시 `dataManager.refreshData()` 수동 호출
- `DataManager`의 `print()` 문을 Xcode 콘솔에서 로깅에 활용
- iOS 기기는 iCloud Drive가 활성화되어 있어야 하고 같은 Apple ID로 로그인되어야 함
- macOS: 시스템 설정 > iCloud에서 동기화 폴더 위치 확인
