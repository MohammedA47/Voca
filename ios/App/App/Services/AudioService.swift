import Foundation
import AVFoundation
import Combine

class AudioService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioService()
    
    @Published var isSpeaking: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var currentTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // TTS audio cache — avoids re-fetching identical pronunciations
    private let audioCache = NSCache<NSString, NSData>()
    
    // Hardcoded config matching AuthService
    private let supabaseUrl = "https://brknoeqgpejhxsqsjnan.supabase.co"
    private let supabaseAnonKey = "sb_publishable_SIqMFd0McVuxDH7u6V_1RA_okuvvVmT"
    
    // ElevenLabs voices mapped by LearnView.swift phonetics mode ("us" or "uk")
    private let voiceIds: [String: String] = [
        "uk": "JBFqnCBsd6RMkjVDRZzb", // George 
        "us": "cjVigY5qzO86Huf0OWal"  // Eric 
    ]
    
    private override init() {
        super.init()
        setupAudioSession()
        audioCache.countLimit = 100
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func speak(text: String, accent: String = "us", speed: Double = 1.0) {
        // Cancel any pending download/playback
        stop()
        
        currentTask = Task { @MainActor in
            self.isSpeaking = true
            
            do {
                let voiceId = voiceIds[accent] ?? voiceIds["us"]!
                let cacheKey = NSString(string: "\(text)_\(accent)_\(speed)")
                
                // Check cache first
                if let cachedData = audioCache.object(forKey: cacheKey) {
                    self.audioPlayer = try AVAudioPlayer(data: cachedData as Data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                    return
                }
                
                guard let url = URL(string: "\(supabaseUrl)/functions/v1/elevenlabs-tts") else {
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
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
                
                // Cache the audio data for future use
                self.audioCache.setObject(data as NSData, forKey: cacheKey)
                
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
    
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

