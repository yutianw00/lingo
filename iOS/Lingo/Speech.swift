import AVFoundation

/// Pronunciation through the system voices (the web app uses speechSynthesis the same way).
@MainActor
enum Speech {
    private static let synth = AVSpeechSynthesizer()

    static func speak(_ text: String, _ lang: Lang) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: lang.voice)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
    }
}
