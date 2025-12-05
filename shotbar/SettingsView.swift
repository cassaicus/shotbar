import SwiftUI

struct SettingsView: View {
    @AppStorage("saveFolderPath") private var saveFolderPath: String = ""
    @AppStorage("filenamePrefix") private var filenamePrefix: String = "capture"
    @AppStorage("arrowKey") private var arrowKey: Int = 125 // Default Down (125)
    @AppStorage("maxCount") private var maxCount: Int = 50
    @AppStorage("initialDelay") private var initialDelay: Double = 5.0
    @AppStorage("intervalDelay") private var intervalDelay: Double = 1.0
    @AppStorage("playCompletionSound") private var playCompletionSound: Bool = false

    var body: some View {
        Form {
            Section(header: Text("保存設定")) {
                HStack {
                    Text("保存先:")
                    TextField("保存先フォルダ", text: $saveFolderPath)
                        .disabled(true) // User should use the button
                    Button("選択...") {
                        selectFolder()
                    }
                }

                HStack {
                    Text("ファイル名接頭辞:")
                    TextField("例: capture", text: $filenamePrefix)
                }
            }

            Section(header: Text("動作設定")) {
                Picker("キー方向:", selection: $arrowKey) {
                    Text("左 (Left)").tag(123)
                    Text("右 (Right)").tag(124)
                    Text("下 (Down)").tag(125)
                    Text("上 (Up)").tag(126)
                }

                HStack {
                    Text("最大撮影回数 (1-999):")
                    TextField("回数", value: $maxCount, formatter: NumberFormatter())
                        .onChange(of: maxCount) { newValue in
                            if newValue < 1 { maxCount = 1 }
                            if newValue > 999 { maxCount = 999 }
                        }
                }

                HStack {
                    Text("開始までの待ち時間 (秒):")
                    TextField("秒", value: $initialDelay, format: .number)
                }

                HStack {
                    Text("繰り返しの待ち時間 (秒):")
                    TextField("秒", value: $intervalDelay, format: .number)
                }
            }

            Section(header: Text("通知")) {
                Toggle("完了時に音を鳴らす", isOn: $playCompletionSound)
            }
        }
        .padding()
        .frame(width: 300, height: 350)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                saveFolderPath = url.path
            }
        }
    }
}
