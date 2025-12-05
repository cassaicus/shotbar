import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit // 追加
internal import Combine

class AutoCaptureEngine: ObservableObject {
    @Published var isRunning = false
    private var timer: Timer?

    func start() {
        // アクセシビリティ権限チェック（キー操作用）
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            print("アクセシビリティ権限が必要です")
            return
        }

        isRunning = true
        // 1秒ごとに実行
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performAction()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func performAction() {
        // 1. カーソルキー（下矢印）を送信
        sendKeyPress(keyCode: 125)

        // 2. 少し待ってからスクリーンショット
        // ScreenCaptureKitは非同期なのでTaskで囲む
        Task {
            // 0.1秒待機（画面スクロールの反映待ち）
            try? await Task.sleep(nanoseconds: 100 * 1_000_000)
            await self.takeScreenshotSCK()
        }
    }

    private func sendKeyPress(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.post(tap: .cghidEventTap)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
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
            
            // 保存処理
            saveImage(cgImage)
            
        } catch {
            print("スクリーンショット撮影エラー: \(error)")
        }
    }
    
    private func saveImage(_ cgImage: CGImage) {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "capture_\(formatter.string(from: Date())).png"
        
        // デスクトップ等のパスを取得
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(fileName)
        
        try? data.write(to: fileURL)
        print("保存完了: \(fileName)")
    }
}
