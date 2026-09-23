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
    private var _currentEffect: MirrorEffect = .normal
    private let effectLock = NSLock()
    var currentEffect: MirrorEffect {
        get {
            effectLock.withLock { _currentEffect }
        }
        set {
            effectLock.withLock { _currentEffect = newValue }
        }
    }
    private let effectEngine = MirrorEffectEngine()
    
    var onFrame: (@MainActor @Sendable (CGImage) -> Void)?

    func configure(completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        queue.async {
            if self.isConfigured {
                Task { @MainActor in
                    completion(true, nil)
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                               AVCaptureDevice.default(for: .video) else {
                self.session.commitConfiguration()
                Task { @MainActor in
                    completion(false, "No camera found on this Mac.")
                }
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
                Task { @MainActor in
                    completion(true, nil)
                }
            } catch {
                self.session.commitConfiguration()
                Task { @MainActor in
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let effect = self.currentEffect
        if let cgImage = self.effectEngine.process(sampleBuffer: sampleBuffer, effect: effect) {
            Task { @MainActor [weak self] in
                self?.onFrame?(cgImage)
            }
        } else {
            print("LAZYNOTCH: effectEngine returned nil")
        }
    }

    func start(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        queue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let running = self.session.isRunning
            Task { @MainActor in
                completion(running)
            }
        }
    }

    func stop(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            let running = self.session.isRunning
            Task { @MainActor in
                completion(running)
            }
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
    private var lifecycleGeneration: UInt64 = 0

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
            self.hasPermission = false
            self.errorMessage = nil
        default:
            self.hasPermission = false
            self.errorMessage = "Camera access denied. Enable in System Settings > Privacy & Security > Camera."
        }
    }

    public func requestAccess(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            self.hasPermission = true
            self.errorMessage = nil
            completion?(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.hasPermission = granted
                    self.errorMessage = granted ? nil : "Camera access denied. Enable in System Settings > Privacy & Security > Camera."
                    completion?(granted)
                }
            }
        default:
            self.hasPermission = false
            self.errorMessage = "Camera access denied. Enable in System Settings > Privacy & Security > Camera."
            completion?(false)
        }
    }

    public func start() {
        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .authorized else {
            if status == .notDetermined {
                requestAccess { [weak self] granted in
                    if granted {
                        self?.start()
                    }
                }
            } else {
                checkPermission()
            }
            return
        }

        worker.configure { [weak self] success, error in
            guard let self, self.lifecycleGeneration == generation else { return }
            if !success {
                self.errorMessage = error
                return
            }

            self.worker.onFrame = { [weak self] cgImage in
                self?.currentFrame = cgImage
            }

            self.worker.start { [weak self] isRunning in
                guard let self, self.lifecycleGeneration == generation else { return }
                self.isRunning = isRunning
            }
        }
    }

    public func stop() {
        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        worker.onFrame = nil
        currentFrame = nil
        worker.stop { [weak self] isRunning in
            guard let self, self.lifecycleGeneration == generation else { return }
            self.isRunning = isRunning
        }
    }
}
