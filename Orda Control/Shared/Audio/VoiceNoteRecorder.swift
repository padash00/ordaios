import Foundation
import SwiftUI
import AVFoundation

// MARK: - Recorder Manager

@MainActor
final class VoiceNoteRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordedURL: URL?
    @Published var elapsedSeconds: Int = 0
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    private var tempURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("voice_note_\(UUID().uuidString).m4a")
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Ошибка настройки аудио"
            return
        }

        let url = tempURL
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            elapsedSeconds = 0
            startTimer()
        } catch {
            errorMessage = "Не удалось начать запись"
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        recordedURL = audioRecorder?.url
        isRecording = false
        stopTimer()
    }

    func startPlayback() {
        guard let url = recordedURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            errorMessage = "Не удалось воспроизвести запись"
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }

    func deleteRecording() {
        stopPlayback()
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        elapsedSeconds = 0
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceNoteRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.errorMessage = "Запись прервана"
            }
            self.isRecording = false
            self.stopTimer()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceNoteRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}

// MARK: - VoiceNoteButton View

struct VoiceNoteButton: View {
    let onAttach: (URL) -> Void

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if recorder.recordedURL == nil {
                // Recording state
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        } else {
                            recorder.startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? AppTheme.Colors.error : AppTheme.Colors.accentPrimary)
                                .frame(width: 44, height: 44)
                            if recorder.isRecording {
                                Circle()
                                    .stroke(AppTheme.Colors.error.opacity(0.4), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(pulse ? 1.4 : 1.0)
                                    .opacity(pulse ? 0 : 1)
                                    .animation(.easeOut(duration: 0.8).repeatForever(autoreverses: false), value: pulse)
                            }
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onAppear { if recorder.isRecording { pulse = true } }
                    .onChange(of: recorder.isRecording) { _, recording in
                        pulse = recording
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recorder.isRecording ? "Запись…" : "Нажмите для записи")
                            .font(AppTheme.Typography.callout)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        if recorder.isRecording {
                            Text(timerLabel(recorder.elapsedSeconds))
                                .font(AppTheme.Typography.monoCaption)
                                .foregroundStyle(AppTheme.Colors.error)
                        } else {
                            Text("Голосовая заметка")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                    }
                }
            } else {
                // Playback / attach state
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Button {
                            if recorder.isPlaying {
                                recorder.stopPlayback()
                            } else {
                                recorder.startPlayback()
                            }
                        } label: {
                            Circle()
                                .fill(AppTheme.Colors.accentBlue)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Запись готова")
                                .font(AppTheme.Typography.callout)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(timerLabel(recorder.elapsedSeconds))
                                .font(AppTheme.Typography.monoCaption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }

                        Spacer()
                    }

                    HStack(spacing: AppTheme.Spacing.xs) {
                        Button {
                            if let url = recorder.recordedURL {
                                onAttach(url)
                            }
                        } label: {
                            Label("Прикрепить", systemImage: "paperclip")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.success)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        }

                        Button {
                            recorder.deleteRecording()
                        } label: {
                            Label("Удалить", systemImage: "trash")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.error)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.errorBg)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.small).stroke(AppTheme.Colors.errorBorder, lineWidth: 1))
                        }
                    }
                }
            }

            if let err = recorder.errorMessage {
                Text(err)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.error)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).stroke(AppTheme.Colors.borderSubtle, lineWidth: 1))
    }

    private func timerLabel(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
