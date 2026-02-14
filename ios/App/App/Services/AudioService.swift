import AVFoundation

class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
    }
    
    func speak(text: String, startDelay: Double = 0) { // Add startDelay param to match signature if needed
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") // Default to UK
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
