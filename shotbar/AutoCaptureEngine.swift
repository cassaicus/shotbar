import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit
internal import Combine

enum ArrowKey: UInt16, CaseIterable, Identifiable {
    case left = 123
    case right = 124
    case down = 125
    case up = 126

    var id: Self { self }

    var displayName: String {
        switch self {
        case .left: return "左 (Left)"
        case .right: return "右 (Right)"
        case .down: return "下 (Down)"
        case .up: return "上 (Up)"
        }
    }
}

class AutoCaptureEngine: ObservableObject {
    @Published var isRunning = false
    // Settings are now retrieved from UserDefaults

    private var currentShotCount = 0
    private var loopTask: Task<Void, Never>? // Timerの代わりにTaskを使用
    private var currentSessionFolderPath: URL?
    private let duplicateDetector: DuplicateDetecting = VisionDuplicateDetector()

    // Settings accessors
    private var arrowKey: UInt16 {
        let val = UserDefaults.standard.object(forKey: "arrowKey") as? Int
        return UInt16(val ?? 125) // Default to Down (125)
    }

    private var maxCount: Int {
        let val = UserDefaults.standard.object(forKey: "maxCount") as? Int
        return val ?? 50
    }

    private var initialDelay: Double {
        let val = UserDefaults.standard.object(forKey: "initialDelay") as? Double
        return val ?? 5.0
    }

    private var intervalDelay: Double {
        let val = UserDefaults.standard.object(forKey: "intervalDelay") as? Double
        return val ?? 1.0
    }

    private var saveFolderPath: String {
        UserDefaults.standard.string(forKey: "saveFolderPath") ?? ""
    }

    private var filenamePrefix: String {
        let val = UserDefaults.standard.string(forKey: "filenamePrefix") ?? ""
        return val.isEmpty ? "capture" : val
    }

    private var completionSound: String {
        UserDefaults.standard.string(forKey: "completionSound") ?? "None"
    }

    private var autoCreateFolder: Bool {
        UserDefaults.standard.bool(forKey: "autoCreateFolder")
    }

    private var detectDuplicate: Bool {
        UserDefaults.standard.bool(forKey: "detectDuplicate")
    }

    private var duplicateThreshold: Double {
        UserDefaults.standard.object(forKey: "duplicateThreshold") as? Double ?? 0.05
    }

    private var countDownSound: String {
        UserDefaults.standard.string(forKey: "countDownSound") ?? "Beep"
    }

    private func playSound(named soundName: String) {
        if soundName == "None" { return }
        if soundName == "Beep" {
            NSSound.beep()
        } else {
            NSSound(named: soundName)?.play()
        }
    }

    private func playCountdownSound() {
        self.playSound(named: self.countDownSound)
    }

    private func playCompletionSoundAction() {
        self.playSound(named: self.completionSound)
    }

    func start() {
        if !checkPermission() {
            print("アクセシビリティ権限が必要です")
            return
        }

        currentShotCount = 0
        isRunning = true
        currentSessionFolderPath = nil

        duplicateDetector.reset()
        duplicateDetector.setThreshold(duplicateThreshold)

        // Capture settings at start of run
        let _initialDelay = self.initialDelay
        let _intervalDelay = self.intervalDelay
        let _maxCount = self.maxCount
        let _arrowKey = self.arrowKey
        let _completionSound = self.completionSound

        if self.autoCreateFolder {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())

            let savePath = self.saveFolderPath
            let baseParamsURL: URL
            if !savePath.isEmpty {
                baseParamsURL = URL(fileURLWithPath: savePath)
            } else {
                baseParamsURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            }

            let newFolderURL = baseParamsURL.appendingPathComponent(timestamp)
            do {
                try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
                currentSessionFolderPath = newFolderURL
                print("Created session folder: \(newFolderURL.path)")
            } catch {
                print("Failed to create session folder: \(error)")
            }
        }

        loopTask?.cancel()
        loopTask = Task {
            // 1. 最初の待ち時間
            if _initialDelay > 0 {
                let delayInt = Int(_initialDelay)
                // 秒数分、音を鳴らして待機
                for _ in 0..<delayInt {
                    if Task.isCancelled { return }
                    await MainActor.run { self.playCountdownSound() }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }

                // 0秒時点の音
                if Task.isCancelled { return }
                await MainActor.run { self.playCountdownSound() }
            }
            if Task.isCancelled { return }

            while !Task.isCancelled {
                // 2. スクリーンショット撮影
                await self.takeScreenshotSCK()
                if Task.isCancelled { break }

                // 3. キー操作
                self.sendKeyPress(keyCode: _arrowKey)

                // カウント処理
                self.currentShotCount += 1
                if self.currentShotCount >= _maxCount {
                    await MainActor.run {
                        self.playSound(named: _completionSound)
                        self.stop()
                    }
                    break
                }

                // 4. 繰り返しの待ち時間
                if _intervalDelay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(_intervalDelay * 1_000_000_000))
                }
            }
        }
    }

    func stop() {
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        currentSessionFolderPath = nil
    }

    func takeSingleShot() {
        if !checkPermission() {
             print("アクセシビリティ権限が必要です")
             return
        }

        let _arrowKey = self.arrowKey

        Task {
            // 1. 1秒待機 (Single shot default wait)
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // 2. スクリーンショット撮影
            await self.takeScreenshotSCK()

            // 3. キー操作
            self.sendKeyPress(keyCode: _arrowKey)
        }
    }

    private func checkPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func sendKeyPress(keyCode: UInt16) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        keyDown?.post(tap: .cghidEventTap)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        keyUp?.post(tap: .cghidEventTap)
    }

    // ScreenCaptureKitを使用した新しいスクリーンショット撮影メソッド
    @MainActor
    private func takeScreenshotSCK() async {
        do {
            // 現在のディスプレイ情報を取得
            let availableContent = try await SCShareableContent.current
            guard let display = availableContent.displays.first else { return }

            // フィルター設定（ディスプレイ全体を撮る、除外アプリなし）
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            // 設定（解像度など）
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            
            // 画像を取得 (macOS 14.0+)
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            // 重複チェック
            if self.detectDuplicate {
                let isDuplicate = await duplicateDetector.isDuplicate(cgImage)

                if isDuplicate {
                    print("重複画像を検知しました。停止します。")
                    await MainActor.run {
                        self.playCompletionSoundAction()
                        self.stop()
                    }
                    return
                }
            }

            // 重複でない場合（またはチェックしない場合）は保存
            saveImage(cgImage)
            
        } catch {
            print("スクリーンショット撮影エラー: \(error)")
        }
    }
    
    private func saveImage(_ cgImage: CGImage) {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return }
        saveImageData(data)
    }

    private func saveImageData(_ data: Data) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let prefix = self.filenamePrefix
        let fileName = "\(prefix)_\(timestamp).png"

        // 保存フォルダの決定
        let destinationURL: URL
        if let sessionURL = currentSessionFolderPath {
            destinationURL = sessionURL
        } else {
            let savePath = self.saveFolderPath
            if !savePath.isEmpty {
                destinationURL = URL(fileURLWithPath: savePath)
            } else {
                // デスクトップ
                destinationURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            }
        }
        
        let fileURL = destinationURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("保存完了: \(fileURL.path)")
        } catch {
            print("保存失敗: \(error)")
        }
    }
}
