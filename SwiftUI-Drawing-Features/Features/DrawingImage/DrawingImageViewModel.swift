//
//  DrawingImageViewModel.swift
//  FloodFillFeature
//
//  Created by Saksham Shrey on 03/05/25.
//

import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

class DrawingImageViewModel: ObservableObject {
    // Current state
    @Published private(set) var currentImage: UIImage?
    @Published private(set) var processedImage: UIImage?
    
    // Stencil creation parameters
    @Published var edgeIntensity: CGFloat = 5.0       // Controls edge detection sensitivity (1-20)
    @Published var threshold: CGFloat = 0.1           // Controls black/white cutoff (0.01-1.0)
    @Published var strokeDistance: CGFloat = 0.5      // Controls line merging (0.0-1.0)
    @Published var lineThickness: CGFloat = 0.5       // Controls thickness of outlines (0.1-2.0)
    @Published var detailLevel: CGFloat = 0.5         // Controls amount of detail (0.0-1.0)
    @Published var smoothingLevel: CGFloat = 0.3      // Controls edge smoothing (0.0-1.0)
    @Published var preserveBlackAreas: Bool = true    // Option to preserve black areas
    @Published var useAdaptiveThreshold: Bool = false // Option to use adaptive thresholding
    @Published var isProcessing: Bool = false
    
    // Processing mode
    enum ProcessingMode: String, CaseIterable, Identifiable {
        case outline = "Outline"
        case stencil = "Stencil"
        case sketch = "Sketch"
        
        var id: String { self.rawValue }
    }
    
    @Published var processingMode: ProcessingMode = .stencil
    
    // History management
    private var imageHistory: [UIImage] = []
    private var historyIndex: Int = -1
    private var initialImage: UIImage?
    
    @Published var savedImage: UIImage?
    
    var canUndo: Bool {
        historyIndex > 0 
    }
    
    var canRedo: Bool {
        historyIndex < imageHistory.count - 1
    }
    
    // Photo picker
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            if let selectedItem = selectedItem {
                loadImage(from: selectedItem)
            }
        }
    }
    
    // Serial queue for handling image processing operations
    private let processOperationQueue = DispatchQueue(label: "com.drawingimage.operationQueue")
    
    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { [weak self] result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.setInitialImage(image)
                    }
                }
            case .failure:
                print("Failed to load image from Photos")
            }
        }
    }
    
    func initializeWithImage(_ image: UIImage) {
        // Only initialize if not already initialized
        if initialImage == nil {
            setInitialImage(image)
        }
    }
    
    private func setInitialImage(_ image: UIImage) {
        self.initialImage = image
        self.imageHistory = [image]
        self.historyIndex = 0
        self.currentImage = image
        self.processedImage = nil
        self.savedImage = nil // Reset saved image when a new image is set
    }
    
    func resetImage() {
        if let initialImage = initialImage {
            self.currentImage = initialImage
            self.processedImage = nil
            self.historyIndex = 0
        } else {
            imageHistory.removeAll()
            historyIndex = -1
            currentImage = nil
            processedImage = nil
        }
    }
    
    func undo() {
        guard canUndo else { return }
        historyIndex -= 1
        processedImage = imageHistory[historyIndex]
    }
    
    func redo() {
        guard canRedo else { return }
        historyIndex += 1
        processedImage = imageHistory[historyIndex]
    }
    
    func saveImage() {
        if let processedImage = processedImage {
            self.savedImage = processedImage
        }
    }
    
    private func addToHistory(_ image: UIImage) {
        // Remove any forward history if we're not at the end
        if historyIndex < imageHistory.count - 1 {
            imageHistory.removeSubrange((historyIndex + 1)...)
        }
        
        // Add the new image to history
        imageHistory.append(image)
        historyIndex = imageHistory.count - 1
        
        // Limit history size
        if imageHistory.count > 20 {
            imageHistory.removeFirst()
            historyIndex -= 1
        }
    }
    
    // Helper method to extract black areas from an image
    private func extractBlackAreas(from ciImage: CIImage, context: CIContext) -> CIImage? {
        // Create a threshold filter to identify dark areas
        let blackThreshold: CGFloat = 0.1 // Adjust this value to define "black"
        
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.contrast = 1.2 // Increase contrast to better separate black areas
        colorControls.brightness = 0.0 // Keep brightness normal
        
        guard let contrastImage = colorControls.outputImage else { return nil }
        
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = contrastImage
        thresholdFilter.threshold = Float(blackThreshold)
        
        guard let blackMask = thresholdFilter.outputImage else { return nil }
        
        return blackMask
    }
    
    // Apply morphological operations to control stroke distance
    private func applyMorphologicalOperations(to ciImage: CIImage, distance: CGFloat, thickness: CGFloat) -> CIImage? {
        // Scale parameters to reasonable pixel values
        let radius = 1 + Int(distance * 10)
        let lineWidth = max(1, Int(thickness * 5))
        
        var currentImage = ciImage
        
        // Apply morphological gradient to detect edges
        if let morphFilter = CIFilter(name: "CIMorphologyGradient") {
            morphFilter.setValue(currentImage, forKey: kCIInputImageKey)
            morphFilter.setValue(radius, forKey: "inputRadius")
            
            if let output = morphFilter.outputImage {
                currentImage = output
            }
        }
        
        // Control stroke thickness and merging based on parameters
        let dilateAmount = Int(distance * 20)
        
        if dilateAmount > 0 {
            // Apply dilation to merge close edges
            if let dilateFilter = CIFilter(name: "CIMorphologyMaximum") {
                dilateFilter.setValue(currentImage, forKey: kCIInputImageKey)
                dilateFilter.setValue(dilateAmount, forKey: "inputRadius")
                
                if let output = dilateFilter.outputImage {
                    currentImage = output
                }
            }
            
            // Apply erosion to thin the merged edges based on desired line thickness
            let erodeAmount = max(1, dilateAmount - lineWidth)
            if let erodeFilter = CIFilter(name: "CIMorphologyMinimum") {
                erodeFilter.setValue(currentImage, forKey: kCIInputImageKey)
                erodeFilter.setValue(erodeAmount, forKey: "inputRadius")
                
                if let output = erodeFilter.outputImage {
                    currentImage = output
                }
            }
        }
        
        return currentImage
    }
    
    // Apply smoothing to edges
    private func applySmoothing(to ciImage: CIImage, amount: CGFloat) -> CIImage {
        // Apply Gaussian blur for smoothing
        let blurRadius = amount * 5.0 // Scale to reasonable blur radius (0-5)
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = ciImage
        blurFilter.radius = Float(blurRadius)
        
        return blurFilter.outputImage ?? ciImage
    }
    
    // Apply adaptive thresholding (locally adaptive threshold for better detail preservation)
    private func applyAdaptiveThreshold(to ciImage: CIImage) -> CIImage? {
        // First convert to grayscale
        let grayscale = CIFilter.colorControls()
        grayscale.inputImage = ciImage
        grayscale.saturation = 0.0 // Remove color
        
        guard let grayscaleImage = grayscale.outputImage else { return nil }
        
        // Apply a small blur to get local average
        let blurFilter = CIFilter.boxBlur()
        blurFilter.inputImage = grayscaleImage
        blurFilter.radius = 10.0 // Radius for local averaging
        
        guard let blurred = blurFilter.outputImage else { return nil }
        
        // Subtract the blurred image from original with offset
        let compositeFilter = CIFilter.differenceBlendMode()
        compositeFilter.inputImage = grayscaleImage
        compositeFilter.backgroundImage = blurred
        
        guard let difference = compositeFilter.outputImage else { return nil }
        
        // Apply threshold to difference image
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = difference
        thresholdFilter.threshold = 0.1 // Threshold for adaptive result
        
        return thresholdFilter.outputImage
    }
    
    // Helper method to convert image to strict black and white (binary)
    private func convertToStrictBlackAndWhite(_ ciImage: CIImage, context: CIContext) -> CIImage? {
        // First convert to grayscale to remove all color information
        let monochromeFilter = CIFilter.colorMonochrome()
        monochromeFilter.inputImage = ciImage
        monochromeFilter.color = CIColor(red: 1, green: 1, blue: 1) // White
        monochromeFilter.intensity = 1.0
        
        guard let grayscaleImage = monochromeFilter.outputImage else { return nil }
        
        // Apply extreme contrast to force black or white
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = grayscaleImage
        colorControls.contrast = 100.0 // Extreme contrast to push pixels to black or white
        colorControls.brightness = 0.0
        colorControls.saturation = 0.0 // No color saturation
        
        guard let highContrastImage = colorControls.outputImage else { return nil }
        
        // Apply threshold to create a true binary image
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = highContrastImage
        thresholdFilter.threshold = 0.5 // Middle threshold for black/white decision
        
        guard let binaryImage = thresholdFilter.outputImage else { return nil }
        
        return binaryImage
    }
    
    // Create an outline only stencil
    private func createOutlineStencil(from ciImage: CIImage) -> CIImage? {
        // Edge detection
        let edgeFilter = CIFilter.edges()
        edgeFilter.inputImage = ciImage
        edgeFilter.intensity = Float(edgeIntensity)
        
        guard let edgeOutput = edgeFilter.outputImage else { return nil }
        
        // Apply line thickness control
        var processedEdges = edgeOutput
        if let thickenedEdges = applyMorphologicalOperations(
            to: edgeOutput,
            distance: strokeDistance,
            thickness: lineThickness
        ) {
            processedEdges = thickenedEdges
        }
        
        // Apply smoothing if needed
        if smoothingLevel > 0.0 {
            processedEdges = applySmoothing(to: processedEdges, amount: smoothingLevel)
        }
        
        // Threshold to create binary image
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = processedEdges
        thresholdFilter.threshold = Float(threshold)
        
        guard let result = thresholdFilter.outputImage else { return nil }
        
        // Invert to get black lines on white background
        let invertFilter = CIFilter.colorInvert()
        invertFilter.inputImage = result
        
        return invertFilter.outputImage
    }
    
    // Create a sketch-like stencil
    private func createSketchStencil(from ciImage: CIImage) -> CIImage? {
        // Create a sketch effect
        guard let colorInverted = CIFilter.colorInvert().apply(to: ciImage),
              let blurred = CIFilter.gaussianBlur().apply(to: colorInverted, parameters: ["inputRadius": Float(smoothingLevel * 5 + 1)]) else {
            return nil
        }
        
        // Create sketch using color dodge blend
        let blendFilter = CIFilter.colorDodgeBlendMode()
        blendFilter.inputImage = blurred
        blendFilter.backgroundImage = ciImage
        
        guard let sketched = blendFilter.outputImage else { return nil }
        
        // Control the detail level
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = sketched
        contrastFilter.contrast = Float(1.0 + detailLevel * 2) // Increase contrast based on detail level
        contrastFilter.saturation = 0 // Remove color
        
        guard let result = contrastFilter.outputImage else { return nil }
        
        // Threshold to make it more stencil-like
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = result
        thresholdFilter.threshold = Float(threshold)
        
        return thresholdFilter.outputImage
    }
    
    // Create a filled stencil with regions that can be colored
    private func createFilledStencil(from ciImage: CIImage) -> CIImage? {
        // Prepare the image by adjusting contrast and removing color
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.contrast = Float(1.0 + detailLevel)
        colorControls.saturation = 0.0 // Remove color
        
        guard let preparedImage = colorControls.outputImage else { return nil }
        
        // Apply edge detection
        let edgeFilter = CIFilter.edges()
        edgeFilter.inputImage = preparedImage
        edgeFilter.intensity = Float(edgeIntensity)
        
        guard let edgeOutput = edgeFilter.outputImage else { return nil }
        
        // Process the lines based on settings
        var processedImage: CIImage
        
        if useAdaptiveThreshold {
            if let adaptiveResult = applyAdaptiveThreshold(to: preparedImage) {
                processedImage = adaptiveResult
            } else {
                processedImage = edgeOutput
            }
        } else {
            // Apply morphology to control line merging and thickness
            if let morphedImage = applyMorphologicalOperations(
                to: edgeOutput,
                distance: strokeDistance,
                thickness: lineThickness
            ) {
                processedImage = morphedImage
            } else {
                processedImage = edgeOutput
            }
            
            // Apply smoothing if needed
            if smoothingLevel > 0.0 {
                processedImage = applySmoothing(to: processedImage, amount: smoothingLevel)
            }
            
            // Apply threshold
            let thresholdFilter = CIFilter.colorThreshold()
            thresholdFilter.inputImage = processedImage
            thresholdFilter.threshold = Float(threshold)
            
            if let thresholdOutput = thresholdFilter.outputImage {
                processedImage = thresholdOutput
            }
        }
        
        // Invert to get black lines on white background
        let invertFilter = CIFilter.colorInvert()
        invertFilter.inputImage = processedImage
        
        return invertFilter.outputImage
    }
    
    func convertToDrawing() {
        guard let inputImage = currentImage else { return }
        
        guard !isProcessing else { return }
        
        isProcessing = true
        
        processOperationQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Convert UIImage to CIImage
            guard let ciImage = CIImage(image: inputImage) else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            // Create a Core Image context
            let context = CIContext(options: nil)
            
            // First convert the input image to grayscale for better processing
            let grayscaleFilter = CIFilter.colorControls()
            grayscaleFilter.inputImage = ciImage
            grayscaleFilter.saturation = 0.0 // Remove all color
            grayscaleFilter.contrast = 1.2 // Slightly increase contrast for better edges
            
            guard let grayscaleImage = grayscaleFilter.outputImage else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            // Extract black areas from original image if preservation is enabled
            var blackAreasMask: CIImage? = nil
            if self.preserveBlackAreas {
                blackAreasMask = self.extractBlackAreas(from: ciImage, context: context)
            }
            
            // Process based on selected mode
            var finalOutput: CIImage?
            
            switch self.processingMode {
            case .outline:
                finalOutput = self.createOutlineStencil(from: grayscaleImage)
            case .stencil:
                finalOutput = self.createFilledStencil(from: grayscaleImage)
            case .sketch:
                finalOutput = self.createSketchStencil(from: grayscaleImage)
            }
            
            guard let output = finalOutput else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            // 4. Combine with black areas mask if preservation is enabled
            var resultImage = output
            if let blackMask = blackAreasMask, self.preserveBlackAreas {
                // Use blend filter to overlay black areas from the original image
                let blendFilter = CIFilter.sourceOverCompositing()
                blendFilter.inputImage = blackMask
                blendFilter.backgroundImage = resultImage
                
                if let blendedOutput = blendFilter.outputImage {
                    resultImage = blendedOutput
                }
            }
            
            // 5. Ensure strict black and white output (no colors or grayscale)
            if let binaryImage = self.convertToStrictBlackAndWhite(resultImage, context: context) {
                resultImage = binaryImage
            }
            
            // Create final UIImage
            guard let cgImage = context.createCGImage(resultImage, from: resultImage.extent) else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            let processedUIImage = UIImage(cgImage: cgImage)
            
            DispatchQueue.main.async {
                self.processedImage = processedUIImage
                self.addToHistory(processedUIImage)
                self.isProcessing = false
            }
        }
    }
}

// Helper extension to make filter application more readable
extension CIFilter {
    func apply(to image: CIImage, parameters: [String: Any] = [:]) -> CIImage? {
        self.setValue(image, forKey: kCIInputImageKey)
        
        for (key, value) in parameters {
            self.setValue(value, forKey: key)
        }
        
        return self.outputImage
    }
} 
