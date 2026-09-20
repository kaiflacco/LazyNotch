import AppKit
import AVFoundation
import Combine
import Foundation

private final class CaptureSessionWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.lazynotch.camera.queue")
    private let outputQueue = DispatchQueue(label: "com.lazynotch.camera.output")
    private var isConfigured = false
    
    // Background state
    var currentEffect: MirrorEffect = .normal
    private let effectEngine = MirrorEffectEngine()
    
    var onFrame: ((CGImage) -> Void)?

    func configure(completion: @escaping @Sendable (Bool, String?) -> Void) {
        queue.async {
            if self.isConfigured {
                completion(true, nil)
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                               AVCaptureDevice.default(for: .video) else {
                self.session.commitConfiguration()
                completion(false, "No camera found on this Mac.")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                output.setSampleBufferDelegate(self, queue: self.outputQueue)
                
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                    print("LAZYNOTCH: Video Data Output added")
                } else {
                    print("LAZYNOTCH: Failed to add Video Data Output")
                }
                
                self.isConfigured = true
                self.session.commitConfiguration()
                completion(true, nil)
            } catch {
                self.session.commitConfiguration()
                completion(false, error.localizedDescription)
            }
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let effect = self.currentEffect
        if let cgImage = self.effectEngine.process(sampleBuffer: sampleBuffer, effect: effect) {
            onFrame?(cgImage)
        } else {
            print("LAZYNOTCH: effectEngine returned nil")
        }
    }

    func start(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
            completion(self.session.isRunning)
        }
    }

    func stop(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            completion(self.session.isRunning)
        }
    }
}

/// Manages camera capture session for the Mirror widget.
/// Carefully manages lifecycle so the green camera indicator LED is only on when actively viewing.
@MainActor
public final class CameraManager: ObservableObject {
    public static let shared = CameraManager()

    @Published public var isRunning: Bool = false
    @Published public var hasPermission: Bool = false
    @Published public var errorMessage: String?
    @Published public var currentFrame: CGImage?
    
    // The active filter/effect
    public var currentEffect: MirrorEffect = .normal {
        didSet {
            worker.currentEffect = currentEffect
        }
    }

    private let worker = CaptureSessionWorker()
    private var cancellables = Set<AnyCancellable>()

    public var captureSession: AVCaptureSession {
        worker.session
    }

    public init() {
        checkPermission()

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkPermission()
            }
            .store(in: &cancellables)

        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermission()
            }
            .store(in: &cancellables)
    }

    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.hasPermission = true
            self.errorMessage = nil
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.hasPermission = granted
                }
            }
        default:
            self.hasPermission = false
            self.errorMessage = "Camera access denied. Enable in System Settings > Privacy & Security > Camera."
        }
    }

    public func start() {
        guard hasPermission else {
            checkPermission()
            return
        }

        worker.configure { [weak self] success, error in
            guard let self = self else { return }
            if !success {
                Task { @MainActor in
                    self.errorMessage = error
                }
                return
            }

            self.worker.start { isRunning in
                Task { @MainActor in
                    self.isRunning = isRunning
                }
            }
            
            self.worker.onFrame = { cgImage in
                Task { @MainActor in
                    CameraManager.shared.currentFrame = cgImage
                }
            }
        }
    }

    public func stop() {
        worker.stop { [weak self] isRunning in
            guard let self = self else { return }
            Task { @MainActor in
                self.isRunning = isRunning
            }
        }
    }
}
