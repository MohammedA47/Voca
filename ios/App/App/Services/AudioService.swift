import Foundation
import AVFoundation

// MARK: - Audio Cache Actor

/// Thread-safe cache for TTS audio data using actor isolation.
///
/// Wraps `NSCache` in an actor to guarantee safe concurrent access
/// from any task without data races.
actor AudioCacheActor {
    private let cache = NSCache<NSString, NSData>()

    init(countLimit: Int = 100) {
        cache.countLimit = countLimit
    }

    /// Returns cached audio data for the given key, or `nil` if not cached.
    func get(_ key: String) -> Data? {
        cache.object(forKey: NSString(string: key)) as Data?
    }

    /// Stores audio data in the cache.
    func set(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: NSString(string: key))
    }
}

// MARK: - Audio Service

/// Fetches and plays TTS audio from the ElevenLabs API via a Supabase edge function.
///
/// Caches audio data in memory via `AudioCacheActor` to avoid re-fetching identical pronunciations.
@Observable
@MainActor
final class AudioService: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioService()

    var isSpeaking: Bool = false

    private var audioPlayer: AVAudioPlayer?
    private var currentTask: Task<Void, Never>?

    /// Actor-isolated TTS audio cache.
    private let audioCache = AudioCacheActor()

    // Hardcoded config matching AuthService
    private let supabaseUrl = "https://brknoeqgpejhxsqsjnan.supabase.co"
    private let supabaseAnonKey = "sb_publishable_SIqMFd0McVuxDH7u6V_1RA_okuvvVmT"

    /// ElevenLabs voices mapped by phonetics mode ("us" or "uk").
    private let voiceIds: [String: String] = [
        "uk": "JBFqnCBsd6RMkjVDRZzb", // George
        "us": "cjVigY5qzO86Huf0OWal"  // Eric
    ]

    private override init() {
        super.init()
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

        currentTask = Task { [weak self] in
            guard let self else { return }
            self.isSpeaking = true

            do {
                let voiceId = self.voiceIds[accent] ?? self.voiceIds["us", default: "cjVigY5qzO86Huf0OWal"]
                let cacheKey = "\(text)_\(accent)_\(speed)"

                // Check actor-isolated cache first
                if let cachedData = await self.audioCache.get(cacheKey) {
                    self.audioPlayer = try AVAudioPlayer(data: cachedData)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                    return
                }

                guard let url = URL(string: "\(self.supabaseUrl)/functions/v1/elevenlabs-tts") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(self.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if httpResponse.statusCode == 429 {
                    print("TTS Rate limit exceeded")
                    throw NSError(domain: "Network", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded."])
                }

                if !(200...299).contains(httpResponse.statusCode) {
                    print("TTS API failed with status \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                    throw URLError(.badServerResponse)
                }

                // Cache the audio data via actor
                await self.audioCache.set(data, forKey: cacheKey)

                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()

            } catch {
                print("Failed to fetch or play TTS audio: \(error.localizedDescription)")
                if !Task.isCancelled {
                    self.isSpeaking = false
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
        isSpeaking = false
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
}
