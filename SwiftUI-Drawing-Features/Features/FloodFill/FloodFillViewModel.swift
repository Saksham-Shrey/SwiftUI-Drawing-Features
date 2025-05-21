//
//  FloodFillViewModel.swift
//  FloodFill-Test
//
//  Created by Saksham Shrey on 03/05/25.
//

import SwiftUI
import PhotosUI

class FloodFillViewModel: ObservableObject {
    // Current state
    @Published private(set) var currentImage: UIImage?
    @Published var selectedColor: Color = .red
    @Published var tolerance: CGFloat = 10
    @Published var isAnimatingFill: Bool = false
    
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
    
    // Serial queue for handling flood fill operations
    private let fillOperationQueue = DispatchQueue(label: "com.floodfill.operationQueue")
    
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
                // Handle error
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
        self.savedImage = nil // Reset saved image when a new image is set
    }
    
    func resetImage() {
        if let initialImage = initialImage {
            // Add the current state to history before resetting
            if let currentImage = currentImage, currentImage != initialImage && historyIndex == imageHistory.count - 1 {
                addToHistory(currentImage)
            }
            
            // Reset to the initial image
            self.currentImage = initialImage
            self.historyIndex = 0
        } else {
            // If no initial image set, just clear the processed image
            imageHistory.removeAll()
            historyIndex = -1
            currentImage = nil
        }
    }
    
    func undo() {
        guard canUndo else { return }
        historyIndex -= 1
        currentImage = imageHistory[historyIndex]
    }
    
    func redo() {
        guard canRedo else { return }
        historyIndex += 1
        currentImage = imageHistory[historyIndex]
    }
    
    func saveImage() {
        if let currentImage = currentImage {
            self.savedImage = currentImage
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
        
        // Limit history size (optional)
        if imageHistory.count > 20 {
            imageHistory.removeFirst()
            historyIndex -= 1
        }
    }
    
    func applyFloodFill(at point: CGPoint, imageFrame: CGRect, image: UIImage, with color: Color, tolerance: CGFloat) {
        // Ensure only one fill operation happens at a time
        guard !isAnimatingFill else { return }
        
        // If using the default image for the first time, initialize history
        if currentImage == nil && initialImage == nil, let testImage = UIImage(named: "testImage") {
            setInitialImage(testImage)
        }
        
        // Convert touch coordinates to image coordinates
        let imageSize = image.size
        let frameSize = imageFrame.size
        
        // Calculate scaling ratio
        let scaleX = imageSize.width / frameSize.width
        let scaleY = imageSize.height / frameSize.height
        
        // Scale touch point to image coordinates
        let imagePoint = CGPoint(
            x: point.x * scaleX,
            y: point.y * scaleY
        )
        
        // Set animating state
        fillOperationQueue.sync {
            self.isAnimatingFill = true
        }
        
        // Use animated flood fill
        FloodFillUtility.animatedFloodFill(
            image: image,
            at: imagePoint,
            with: UIColor(color),
            tolerance: tolerance,
            updateInterval: 3000,
            onProgress: { [weak self] updatedImage in
                guard let self = self else { return }
                
                // Update the current image on the main thread
                DispatchQueue.main.async {
                    self.currentImage = updatedImage
                }
            },
            onCompletion: { [weak self] in
                guard let self = self else { return }
                
                // Set animating to false as soon as the fill is complete
                DispatchQueue.main.async {
                    self.fillOperationQueue.sync {
                        self.isAnimatingFill = false
                        
                        // Add the final result to history
                        if let currentImage = self.currentImage {
                            self.addToHistory(currentImage)
                        }
                    }
                }
            }
        )
        
        // Fallback timer in case the completion handler doesn't get called
        // Set a much shorter timeout (0.3s) as we should rarely need this
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.fillOperationQueue.sync {
                if self.isAnimatingFill {
                    self.isAnimatingFill = false
                    
                    // Ensure we have the latest image in history
                    if let currentImage = self.currentImage {
                        self.addToHistory(currentImage)
                    }
                }
            }
        }
    }
}
