import AVFoundation

class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking: Bool = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(text: String, startDelay: Double = 0) {
        // If already speaking, stop first
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
