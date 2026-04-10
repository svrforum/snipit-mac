import AppKit
import Foundation
import ScreenCaptureKit

@Observable
final class RecordingViewModel {

    // MARK: - Dependencies

    private let recordingService = RecordingService()
    private let storageService: StorageService

    // MARK: - State

    var isRecording = false
    var recordingMode: RecordingMode = .gif
    var duration: TimeInterval = 0
    var frameCount = 0
    var outputURL: URL?
    var errorMessage: String?

    private var timer: Timer?

    // MARK: - Initialization

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    // MARK: - Start Recording

    func startRecording(
        mode: RecordingMode,
        region: CGRect,
        display: SCDisplay,
        settings: AppSettings
    ) async {
        do {
            recordingMode = mode
            isRecording = true
            errorMessage = nil
            outputURL = nil
            duration = 0
            frameCount = 0

            try storageService.ensureDirectories()

            startProgressTimer()

            try await recordingService.startRecording(
                mode: mode,
                region: region,
                display: display,
                fps: settings.recordingFPS.rawValue,
                gifQuality: settings.gifQuality,
                videoCodec: settings.videoCodec,
                maxDuration: settings.maxRecordingDuration,
                outputDirectory: storageService.recordingsDirectory
            )
        } catch {
            isRecording = false
            stopProgressTimer()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Stop Recording

    func stopRecording() async {
        stopProgressTimer()

        do {
            let url = try await recordingService.stopRecording()
            outputURL = url
            isRecording = false
        } catch {
            isRecording = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Cancel Recording

    func cancelRecording() async {
        stopProgressTimer()
        await recordingService.cancelRecording()
        isRecording = false
        outputURL = nil
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func updateProgress() async {
        duration = await recordingService.recordingDuration
        frameCount = await recordingService.frameCount

        let stillRecording = await recordingService.isRecording
        if !stillRecording && isRecording {
            // Recording stopped externally (e.g., max duration reached)
            isRecording = false
            stopProgressTimer()
        }
    }
}
