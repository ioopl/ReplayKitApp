import Foundation
import Combine

/// The hashing pipeline to use when computing SHA-256 integrity digests.
///
public enum HashingPipeline: String, CaseIterable {
    
    /// Pipeline 1 (default): Hash the raw captured CVPixelBuffer bytes before any JPEG encoding.
    case pixelBuffer = "pixelBuffer"
   
    /// Pipeline 2: Encode to JPEG first, then hash the compressed JPEG bytes.
    case jpegFirst = "jpegFirst"

    public var displayName: String {
        switch self {
        case .pixelBuffer: return "Hash Original Frame (Pixel Buffer)"
        case .jpegFirst:   return "Hash JPEG-First (Compressed Payload)"
        }
    }

    public var description: String {
        switch self {
        case .pixelBuffer:
            return "SHA-256 is computed directly over the raw, uncompressed CVPixelBuffer bytes — identical to what the sensor captured. Highest fidelity, largest data surface."
        case .jpegFirst:
            return "The frame is JPEG-encoded first, then SHA-256 is computed over the compressed bytes — matching the actual payload that would be transmitted or stored."
        }
    }
}

/// Shared app-wide capture settings backed by `UserDefaults` / `AppStorage`.
public final class CaptureSettings: ObservableObject {
    public static let shared = CaptureSettings()

    @Published public var hashingPipeline: HashingPipeline {
        didSet {
            let raw = hashingPipeline.rawValue
            UserDefaults.standard.set(raw, forKey: Keys.hashingPipeline)
            // Also write to shared App Group so SampleHandler (broadcast extension) can read it
            UserDefaults(suiteName: Keys.appGroup)?.set(raw, forKey: Keys.hashingPipeline)
        }
    }

    private enum Keys {
        static let hashingPipeline = "captureSettings.hashingPipeline"
        static let appGroup = "group.com.apkia.replaykitapp.shared-group"
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Keys.hashingPipeline) ?? ""
        hashingPipeline = HashingPipeline(rawValue: raw) ?? .pixelBuffer
        // Sync initial value to App Group on first launch too
        UserDefaults(suiteName: Keys.appGroup)?.set(hashingPipeline.rawValue, forKey: Keys.hashingPipeline)
    }
}
