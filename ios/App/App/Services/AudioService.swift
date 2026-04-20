import Foundation
import AVFoundation

// MARK: - Audio Cache Actor

/// Thread-safe cache for TTS audio data using actor isolation.
///
/// Wraps `NSCache` in an actor to guarantee safe concurrent access
/// from any task without data races.
actor AudioCacheActor {
    private let cache = NSCache<NSString, NSData>()

    init(countLimit: Int = 100, totalCostLimit: Int = 50 * 1024 * 1024) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    /// Returns cached audio data for the given key, or `nil` if not cached.
    func get(_ key: String) -> Data? {
        cache.object(forKey: NSString(string: key)) as Data?
    }

    /// Stores audio data in the cache with cost-based eviction.
    func set(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: NSString(string: key), cost: data.count)
    }
}

// MARK: - Audio Service

/// Fetches and plays TTS audio from the ElevenLabs API via a Supabase edge function.
///
/// Caches audio data in memory via `AudioCacheActor` to avoid re-fetching identical pronunciations.
@Observable
@MainActor
final class AudioService: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = AudioService()
    private static let networkSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    var isSpeaking: Bool = false
    var lastError: String? = nil

    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentTask: Task<Void, Never>?

    /// Actor-isolated TTS audio cache.
    private let audioCache = AudioCacheActor()

    /// ElevenLabs voices mapped by phonetics mode ("us" or "uk").
    private let voiceIds: [String: String] = [
        "uk": "JBFqnCBsd6RMkjVDRZzb", // George
        "us": "cjVigY5qzO86Huf0OWal"  // Eric
    ]

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    /// Downloads and plays TTS audio for the given text.
    ///
    /// - Parameters:
    ///   - text: The word or phrase to pronounce.
    ///   - accent: `"us"` or `"uk"` accent selection.
    ///   - speed: Playback speed multiplier (1.0 = normal).
    func speak(text: String, accent: String = "us", speed: Double = 1.0) {
        // Cancel any pending download/playback
        stop()

        // Clear previous error
        lastError = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            self.isSpeaking = true

            do {
                let voiceId = self.voiceIds[accent] ?? self.voiceIds["us", default: "cjVigY5qzO86Huf0OWal"]
                let cacheKey = "\(text.lowercased())_\(accent)_\(String(format: "%.2f", speed))"

                // Check actor-isolated cache first
                if let cachedData = await self.audioCache.get(cacheKey) {
                    self.audioPlayer = try AVAudioPlayer(data: cachedData)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.prepareToPlay()
                    if self.audioPlayer?.play() == true {
                        return
                    }

                    self.playSystemSpeech(text: text, accent: accent, speed: speed)
                    return
                }

                guard let url = URL(string: "\(Config.supabaseUrl)/functions/v1/elevenlabs-tts") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 20

                // Add Authorization header if logged in to get higher rate limits
                if let token = AuthService.shared.sessionToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }

                let body: [String: Any] = [
                    "text": text,
                    "voiceId": voiceId,
                    "speed": speed
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await Self.networkSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if httpResponse.statusCode == 429 {
                    print("TTS Rate limit exceeded")
                    self.lastError = "Too many requests. Please wait a moment."
                    throw NSError(domain: "Network", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded."])
                }

                if !(200...299).contains(httpResponse.statusCode) {
                    print("TTS API failed with status \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                    self.lastError = "Network error. Check your connection."
                    throw URLError(.badServerResponse)
                }

                // Cache the audio data via actor
                await self.audioCache.set(data, forKey: cacheKey)

                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                if self.audioPlayer?.play() != true {
                    self.playSystemSpeech(text: text, accent: accent, speed: speed)
                }

            } catch {
                print("Failed to fetch or play TTS audio: \(error.localizedDescription)")
                if !Task.isCancelled {
                    self.playSystemSpeech(text: text, accent: accent, speed: speed)
                }
            }
        }
    }

    /// Stops any in-progress audio playback.
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func playSystemSpeech(text: String, accent: String, speed: Double) {
        audioPlayer?.stop()
        audioPlayer = nil

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = accent == "uk"
            ? AVSpeechSynthesisVoice(language: "en-GB")
            : AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = speechRate(for: speed)

        lastError = nil
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }

    private func speechRate(for speed: Double) -> Float {
        let clampedSpeed = min(max(speed, 0.7), 1.2)
        let normalized = (clampedSpeed - 0.7) / 0.5
        return 0.42 + Float(normalized) * 0.12
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}
