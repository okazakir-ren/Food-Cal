import SwiftUI
import UIKit
import WidgetKit

/// 試作の画面。今日の値、初回設定、検証ログだけを置く。
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: DaySnapshot?
    @State private var weightText = ""
    @State private var needsAuthorization = true
    @State private var events: [DiagnosticEvent] = []
    @State private var message: String?

    private let store = SharedStore()
    private let reader = HealthReader()

    var body: some View {
        NavigationStack {
            List {
                todaySection
                setupSection
                diagnosticsSection
                #if DEBUG && targetEnvironment(simulator)
                Section("開発用") {
                    NavigationLink("ウィジェットの表示確認") { WidgetGalleryView() }
                }
                #endif
            }
            .navigationTitle("あるいてごはん")
            #if DEBUG && targetEnvironment(simulator)
            .navigationDestination(isPresented: .constant(DebugBootstrap.opensGallery)) { WidgetGalleryView() }
            #endif
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await reload() }
        }
    }

    private var todaySection: some View {
        Section("今日") {
            if let snapshot {
                MediumGohanView(display: snapshot.display)
                    .frame(height: 170)
                    .background(Theme.background)
                    .listRowInsets(EdgeInsets())
                if let lastReadAt = snapshot.lastReadAt {
                    LabeledContent("最後に読めた時刻", value: lastReadAt.formatted(date: .omitted, time: .shortened))
                }
                LabeledContent("使っている体重", value: String(format: "%.1fkg", snapshot.weightKg))
            } else {
                Text("初回設定を終えると表示します。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var setupSection: some View {
        Section {
            if needsAuthorization {
                Button("ヘルスケアの読み取りを許可") {
                    Task { await requestAuthorization() }
                }
            }
            HStack {
                TextField("体重（kg）", text: $weightText)
                    .keyboardType(.decimalPad)
                Button("保存") { saveManualWeight() }
                    .disabled(store.isWeightFromHealth)
            }
            .disabled(store.isWeightFromHealth)
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("設定")
        } footer: {
            Text(store.isWeightFromHealth
                 ? "体重はヘルスケアの最新の値を使っています。"
                 : "ヘルスケアに体重がないときは、ここに入力してください。歩数が0のままのときは、設定 › プライバシーとセキュリティ › ヘルスケアを確認してください。")
        }
    }

    private var diagnosticsSection: some View {
        Section("検証ログ") {
            Text(appGroupStatus).font(.footnote)
            ForEach(DiagnosticSummary.make(events: events, since: .now.addingTimeInterval(-24 * 3600)), id: \.source) { row in
                LabeledContent(row.source.rawValue) {
                    Text("24時間で\(row.total)回・失敗\(row.failed)・最後 \(row.lastAt?.formatted(date: .omitted, time: .shortened) ?? "なし")")
                        .font(.footnote)
                }
            }
            Button("ログをコピー") {
                UIPasteboard.general.string = DiagnosticLog.exportText()
                message = "ログをコピーしました。"
            }
            ForEach(events.suffix(30).reversed()) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.at.formatted(date: .abbreviated, time: .standard)) \(event.source.rawValue) \(event.action)")
                    Text(event.error ?? "歩数 \(event.steps.map(String.init) ?? "-")")
                        .foregroundStyle(event.succeeded ? Color.secondary : Color.red)
                }
                .font(.caption)
            }
        }
    }

    private var appGroupStatus: String {
        "App Group: \(store.isAvailable ? "使える" : "使えない") / 保護データ: \(UIApplication.shared.isProtectedDataAvailable ? "読める" : "読めない")"
    }

    private func reload() async {
        needsAuthorization = await reader.needsAuthorizationRequest()
        if !needsAuthorization { store.isAuthorizationRequested = true }
        BackgroundDelivery.shared.startIfAuthorized()
        await syncWeightFromHealth()
        snapshot = await TodayRefresher.refresh(source: .app, action: "foreground")
        WidgetCenter.shared.reloadAllTimelines()
        if let weight = store.weightKg, weightText.isEmpty { weightText = String(format: "%.1f", weight) }
        events = DiagnosticLog.readAll()
    }

    private func requestAuthorization() async {
        do {
            try await reader.requestAuthorization()
            store.isAuthorizationRequested = true
            message = nil
        } catch {
            message = "許可画面を出せませんでした: \(error.localizedDescription)"
        }
        await reload()
    }

    /// ヘルスケアに体重があれば優先する。なければ手入力の値を残す。
    private func syncWeightFromHealth() async {
        guard store.isAuthorizationRequested, let weight = try? await reader.latestWeightKg() else {
            store.isWeightFromHealth = false
            return
        }
        store.weightKg = weight
        store.isWeightFromHealth = true
        weightText = String(format: "%.1f", weight)
    }

    private func saveManualWeight() {
        guard let weight = Double(weightText), (20...300).contains(weight) else {
            message = "体重は20〜300kgで入力してください。"
            return
        }
        store.weightKg = weight
        message = "体重を保存しました。"
        Task { await reload() }
    }
}
