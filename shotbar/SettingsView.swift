import SwiftUI

struct SettingsView: View {
    @AppStorage("saveFolderPath") private var saveFolderPath: String = ""
    @AppStorage("autoCreateFolder") private var autoCreateFolder: Bool = false
    @AppStorage("filenamePrefix") private var filenamePrefix: String = "capture"
    @AppStorage("arrowKey") private var arrowKey: Int = 125 // Default Down (125)
    @AppStorage("maxCount") private var maxCount: Int = 50
    @AppStorage("initialDelay") private var initialDelay: Double = 5.0
    @AppStorage("intervalDelay") private var intervalDelay: Double = 1.0
    @AppStorage("detectDuplicate") private var detectDuplicate: Bool = false
    @AppStorage("duplicateThreshold") private var duplicateThreshold: Double = 0.05
    @AppStorage("playCompletionSound") private var playCompletionSound: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // 保存設定セクション
            GroupBox(label: Label("保存設定", systemImage: "folder.badge.gear")) {
                Grid(alignment: .leading, verticalSpacing: 12) {
                    GridRow {
                        Label("保存先:", systemImage: "folder")
                            .gridColumnAlignment(.leading)
                            .help("スクリーンショットの保存先フォルダ")

                        HStack {
                            Text(saveFolderPath.isEmpty ? "未選択 (デスクトップ)" : saveFolderPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(saveFolderPath.isEmpty ? .secondary : .primary)
                                .help(saveFolderPath)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )

                            Button("選択...") {
                                selectFolder()
                            }
                        }
                    }
                    
                    GridRow {
                        Color.clear
                            .gridColumnAlignment(.leading)
                            .frame(width: 0, height: 0)

                        Toggle("保存時に自動でフォルダを作成する", isOn: $autoCreateFolder)
                            .toggleStyle(.checkbox)
                            .help("撮影開始時に日時名のフォルダを作成し、そこに保存します")
                    }
                    
                    GridRow {
                        Label("ファイル名:", systemImage: "pencil")
                            .help("保存されるファイルの先頭に付く文字列")

                        TextField("例: capture", text: $filenamePrefix)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            // 動作設定セクション
            GroupBox(label: Label("動作設定", systemImage: "camera.badge.ellipsis")) {
                Grid(alignment: .leading, verticalSpacing: 12) {
                    GridRow {
                        Label("キー方向:", systemImage: "arrowkeys")
                            .gridColumnAlignment(.leading)
                            .help("撮影後に送信されるキー入力")

                        Picker("", selection: $arrowKey) {
                            Text("左 (Left)").tag(123)
                            Text("右 (Right)").tag(124)
                            Text("下 (Down)").tag(125)
                            Text("上 (Up)").tag(126)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    GridRow {
                        Label("最大撮影回数:", systemImage: "number")
                            .help("自動撮影を行う最大回数")

                        HStack {
                            TextField("回数", value: $maxCount, formatter: NumberFormatter())
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Stepper("", value: $maxCount, in: 1...999)
                                .labelsHidden()
                            Text("回")
                        }
                        .onChange(of: maxCount) { oldValue, newValue in
                            if newValue < 1 { maxCount = 1 }
                            if newValue > 999 { maxCount = 999 }
                        }
                    }

                    GridRow {
                        Label("開始待ち時間:", systemImage: "timer")
                            .help("撮影開始までの待機時間")

                        HStack {
                            TextField("秒", value: $initialDelay, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("秒")
                        }
                    }

                    GridRow {
                        Label("撮影間隔:", systemImage: "clock.arrow.circlepath")
                            .help("撮影ごとの待機時間")

                        HStack {
                            TextField("秒", value: $intervalDelay, format: .number)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("秒")
                        }
                    }

                    GridRow {
//                        Color.clear
//                            .gridColumnAlignment(.leading)
//                            .frame(width: 0, height: 0)
                        
                        Label("停止条件:", systemImage: "stop.circle.fill")
                            .help("撮影ごとの待機時間")
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Toggle("画像の重複を検知したら撮影を停止", isOn: $detectDuplicate)
                                    .toggleStyle(.checkbox)
                                    .help("直前に撮影した画像と類似している場合、撮影を終了します")
                            }

                            if detectDuplicate {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("判定の厳しさ:")
                                            .font(.caption)
                                        Slider(value: $duplicateThreshold, in: 0.0...0.5, step: 0.01)
                                            .frame(width: 100)
                                        Text("\(duplicateThreshold, specifier: "%.2f")")
                                            .font(.caption)
                                            .monospacedDigit()
                                    }

                                    Text("推薦値: 0.25 (0.00は完全一致で停止)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                                .help("値が小さいほど厳密に判定します (0.00 = 完全一致)。時計の秒数などを無視したい場合は数値を上げてください。")
                            }
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            // 通知セクション
            GroupBox(label: Label("通知", systemImage: "bell.badge")) {
                HStack {
                    Toggle("完了時に音を鳴らす", isOn: $playCompletionSound)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 480) // UI要素に合わせて少し広げる
        .fixedSize(horizontal: true, vertical: true)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        panel.message = "保存先フォルダを選択してください"

        if panel.runModal() == .OK {
            if let url = panel.url {
                saveFolderPath = url.path
            }
        }
    }
}

// プレビュー用 (macOS環境でのみ有効)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
