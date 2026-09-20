import AVFoundation
import CoreImage
import CoreGraphics
import Vision
import AppKit

public enum MirrorEffect: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case lovestruck = "Lovestruck"
    case dizzy = "Dizzy"
    case money = "Money"
    public var id: String { rawValue }
}

public final class MirrorEffectEngine {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var sequenceHandler = VNSequenceRequestHandler()
    private var faceRect: CGRect?
    
    // Animation state
    private var lastTime: CFTimeInterval = 0
    private var elapsedTime: CFTimeInterval = 0
    
    private var cachedImages: [String: CGImage] = [:]
    
    public init() {}
    
    public func process(sampleBuffer: CMSampleBuffer, effect: MirrorEffect) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if effect == .normal {
            return context.createCGImage(ciImage, from: bounds)
        }
        
        // Update time
        let now = CACurrentMediaTime()
        if lastTime == 0 { lastTime = now }
        elapsedTime += (now - lastTime)
        lastTime = now
        
        // Detect Face
        let request = VNDetectFaceRectanglesRequest { [weak self] req, err in
            if let results = req.results as? [VNFaceObservation], let first = results.first {
                let bbox = first.boundingBox
                let w = bbox.width * width
                let h = bbox.height * height
                let x = bbox.origin.x * width
                let y = bbox.origin.y * height
                self?.faceRect = CGRect(x: x, y: y, width: w, height: h)
            } else {
                self?.faceRect = nil
            }
        }
        
        try? sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        
        // No CoreImage distortions for Lovestruck/Dizzy on Mac Photo Booth - just the emojis.
        
        // Draw
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let cgContext = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return context.createCGImage(ciImage, from: bounds)
        }
        
        // Draw original frame
        if let baseCG = context.createCGImage(ciImage, from: bounds) {
            cgContext.draw(baseCG, in: bounds)
        }
        
        // Draw effects
        if let face = faceRect {
            drawEffects(context: cgContext, face: face, effect: effect, bounds: bounds)
        }
        
        return cgContext.makeImage()
    }
    
    private func drawEffects(context: CGContext, face: CGRect, effect: MirrorEffect, bounds: CGRect) {
        let centerX = face.midX
        let topY = face.maxY // Vision origin is bottom-left, so maxY is the TOP of the head
        
        switch effect {
        case .lovestruck:
            drawLovestruck(context: context, centerX: centerX, topY: topY, bounds: bounds)
        case .dizzy:
            drawDizzy(context: context, centerX: centerX, topY: topY)
        case .money:
            drawMoney(context: context, centerX: centerX, topY: topY)
        case .normal:
            break
        }
    }
    
    private func loadPhotoBoothAsset(named: String) -> CGImage? {
        if let cached = cachedImages[named] { return cached }
        let path = "/System/Applications/Photo Booth.app/Contents/Resources/\(named).png"
        guard let dataProvider = CGDataProvider(filename: path),
              let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return nil
        }
        cachedImages[named] = image
        return image
    }

    private func drawLovestruck(context: CGContext, centerX: CGFloat, topY: CGFloat, bounds: CGRect) {
        // A tighter arc of 5 hearts floating up
        let time = elapsedTime
        
        let numHearts = 5
        let faceW = faceRect?.width ?? 150
        let arcWidth = faceW * 0.9
        let heartImages = ["smallHeart", "mediumHeart", "largeHeart"]
        
        for i in 0..<numHearts {
            let offset = Double(i) * 0.6
            let speed: Double = 1.2
            let t = time * speed + offset
            
            let cycle = t.truncatingRemainder(dividingBy: 2.5)
            let yProgress = CGFloat(cycle / 2.5)
            
            let y = topY + (faceRect?.height ?? 100) * 0.1 + (yProgress * faceW * 0.6)
            let xSpread = arcWidth * CGFloat(Double(i) / Double(numHearts - 1) - 0.5)
            let xOffset = sin(t * 3.0 + offset) * 10.0
            let x = centerX + xSpread + xOffset
            let alpha = sin(yProgress * .pi)
            
            let imgName = heartImages[i % heartImages.count]
            let size = faceW * 0.25 // scale relative to face
            
            if let cgImage = loadPhotoBoothAsset(named: imgName) {
                context.saveGState()
                context.setAlpha(alpha)
                
                context.translateBy(x: x, y: y)
                // Remove Y-flip, assuming it's natively right-side up
                let drawRect = CGRect(x: -size/2, y: -size/2, width: size, height: size)
                
                context.draw(cgImage, in: drawRect)
                context.restoreGState()
            } else {
                drawEmoji("🩷", in: context, at: CGPoint(x: x, y: y), size: size, alpha: alpha)
            }
        }
    }
    
    private func drawDizzy(context: CGContext, centerX: CGFloat, topY: CGFloat) {
        // A tight halo of 6 birds spinning fast
        let faceW = faceRect?.width ?? 150
        let radiusX: CGFloat = faceW * 0.55
        let radiusY: CGFloat = radiusX * 0.25
        let time = elapsedTime
        let speed: Double = -2.5 // Slower spin
        
        let numBirds = 6
        for i in 0..<numBirds {
            let offset = (Double(i) / Double(numBirds)) * .pi * 2
            let angle = time * speed + offset
            
            let x = centerX + cos(angle) * radiusX
            let y = topY + (faceRect?.height ?? 100) * 0.1 + sin(angle) * radiusY
            
            let scale = 0.8 + (sin(angle) * 0.2)
            let zIndexAlpha = 0.7 + (sin(angle) * 0.3)
            
            let flapSpeed = 8.0 // Slower flapping
            let frameIndex = Int((time * flapSpeed + Double(i * 2))) % 4
            let birdTypes = ["birdLarge", "birdMedium", "birdSmall"]
            let birdType = birdTypes[i % birdTypes.count]
            let imgName = "\(birdType)\(frameIndex)"
            
            let size = faceW * 0.22 * scale // Scale relative to face
            
            if let cgImage = loadPhotoBoothAsset(named: imgName) {
                let movingRight = sin(angle) > 0
                
                context.saveGState()
                context.setAlpha(zIndexAlpha)
                
                context.translateBy(x: x, y: y)
                // Flip X if moving right, but no Y flip
                let scaleX: CGFloat = movingRight ? -1.0 : 1.0
                context.scaleBy(x: scaleX, y: 1.0)
                
                let drawRect = CGRect(x: -size/2, y: -size/2, width: size, height: size)
                context.draw(cgImage, in: drawRect)
                context.restoreGState()
            } else {
                drawEmoji("🐦", in: context, at: CGPoint(x: x, y: y), size: size, alpha: zIndexAlpha)
            }
        }
    }
    
    private func drawMoney(context: CGContext, centerX: CGFloat, topY: CGFloat) {
        // A unique "Wavy Orbit" of cash circling the head (like dizzy but floats up and down in a sine wave)
        let faceW = faceRect?.width ?? 150
        let radiusX: CGFloat = faceW * 0.75
        let radiusY: CGFloat = radiusX * 0.25
        let time = elapsedTime
        let speed: Double = 1.8 // graceful orbit speed
        
        let numBills = 8
        for i in 0..<numBills {
            let offset = (Double(i) / Double(numBills)) * .pi * 2
            let angle = time * speed + offset
            
            let x = centerX + cos(angle) * radiusX
            
            // Wavy Y offsets create a dynamic roller-coaster orbit instead of a flat ring
            let wavyY = sin(angle * 3.0) * (faceW * 0.15)
            
            // Base Y is the ellipse depth (sin(angle) * radiusY) + the wavy offset
            let y = topY + (faceRect?.height ?? 100) * 0.15 + sin(angle) * radiusY + wavyY
            
            // 3D scale based on depth (front vs back of the orbit)
            let depthScale = 0.75 + (sin(angle) * 0.25)
            let zIndexAlpha = 0.5 + (sin(angle) * 0.5) // fade out beautifully as it goes behind the head
            
            let isFlyingCash = i % 2 == 0
            let emoji = isFlyingCash ? "💸" : "💵"
            
            let emojiSize = faceW * 0.28 * depthScale
            
            // Make the bills slowly tumble on their own axis as they orbit
            let spinRotation = (time * 1.5) + Double(i * 45)
            
            context.saveGState()
            context.setAlpha(zIndexAlpha)
            context.translateBy(x: x, y: y)
            context.rotate(by: CGFloat(spinRotation))
            
            drawEmoji(emoji, in: context, at: CGPoint(x: 0, y: 0), size: emojiSize, alpha: zIndexAlpha)
            context.restoreGState()
        }
    }
    
    private func drawEmoji(_ emoji: String, in context: CGContext, at point: CGPoint, size: CGFloat, alpha: CGFloat) {
        let nsFont = NSFont.systemFont(ofSize: size)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        
        let attrString = NSAttributedString(string: emoji, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        
        context.saveGState()
        context.setAlpha(alpha)
        context.textPosition = CGPoint(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
