import AppKit
import Foundation
import ScreenCaptureKit

@Observable
final class RecordingViewModel {

    // MARK: - Dependencies

    let recordingService = RecordingService()
    private let storageService: StorageService

    // MARK: - State

    var isRecording = false
    var recordingMode: RecordingMode = .gif
    var duration: TimeInterval = 0
    var frameCount = 0
    var outputURL: URL?
    var errorMessage: String?

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
        debugLog("RecordingVM.startRecording mode=\(mode.rawValue) region=\(region)")
        do {
            recordingMode = mode
            isRecording = true
            errorMessage = nil
            outputURL = nil
            duration = 0
            frameCount = 0

            try storageService.ensureDirectories()

            try await recordingService.startRecording(
                mode: mode,
                region: region,
                display: display,
                fps: settings.recordingFPS.rawValue,
                gifQuality: settings.gifQuality,
                gifMaxWidth: settings.gifMaxWidth.rawValue,
                showCursor: settings.showCursorInRecording,
                videoCodec: settings.videoCodec,
                maxDuration: settings.maxRecordingDuration,
                outputDirectory: storageService.recordingsDirectory
            )
            debugLog("RecordingVM: recording started successfully")
        } catch {
            isRecording = false
            errorMessage = error.localizedDescription
            debugLog("RecordingVM start error: \(error)")
        }
    }

    // MARK: - Stop Recording

    func stopRecording() async {
        debugLog("RecordingVM stopping... frames=\(frameCount)")

        do {
            let url = try await recordingService.stopRecording()
            outputURL = url
            isRecording = false
            debugLog("RecordingVM saved: \(url?.path ?? "nil")")
        } catch {
            isRecording = false
            errorMessage = error.localizedDescription
            debugLog("RecordingVM stop error: \(error)")
        }
    }

    // MARK: - Cancel Recording

    func cancelRecording() {
        recordingService.cancelRecording()
        isRecording = false
        outputURL = nil
    }
}
