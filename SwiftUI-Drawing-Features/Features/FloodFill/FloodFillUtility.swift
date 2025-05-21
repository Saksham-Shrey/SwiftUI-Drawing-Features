//
//  FloodFillUtility.swift
//  FloodFill-Test
//
//  Created on 03/05/25.
//

import UIKit
import SwiftUI

struct FloodFillUtility {
    /// Performs a flood fill operation on the image at the specified point with the given color
    /// - Parameters:
    ///   - image: The source UIImage to modify
    ///   - point: The starting point for the flood fill
    ///   - fillColor: The color to fill with
    ///   - tolerance: The color tolerance (0-100) for matching similar colors. Higher values will fill more pixels.
    /// - Returns: A new UIImage with the flood fill applied, or nil if the operation failed
    static func floodFill(image: UIImage, at point: CGPoint, with fillColor: UIColor, tolerance: CGFloat = 10) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        // Create a correctly formatted bitmap context
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        // Create a new context with a known format
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // Draw the original image into the context
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: rect)
        
        // Convert point to integers for array indexing
        let x = Int(point.x)
        let y = Int(point.y)
        
        // Make sure point is within bounds
        guard x >= 0, y >= 0, x < width, y < height else {
            return nil
        }
        
        // Get the image data
        guard let data = context.data else {
            return nil
        }
        
        let dataPtr = data.bindMemory(to: UInt32.self, capacity: width * height)
        
        // Get the color at target point
        let targetColor = dataPtr[y * width + x]
        
        // Check if clicked on a black or very dark edge (we don't want to fill edges)
        if isBlackOrDarkEdge(targetColor) {
            return image
        }
        
        // Extract color components directly from the UIColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        fillColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Create a color for testing to determine the actual format used
        let testColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // Pure red
        _ = createColorPixel(testColor, bitmapInfo: bitmapInfo)
        
        // Now create the fill color pixel using the same format
        let fillColorValue = createColorPixel(fillColor, bitmapInfo: bitmapInfo)
        
        // Scale tolerance from percentage to actual color range
        let toleranceValue = UInt32(tolerance * 2.55) // Scale from 0-100 to 0-255
        
        if colorDifference(targetColor, fillColorValue) <= toleranceValue {
            return image
        }
        
        // Perform flood fill
        floodFillQueue(
            dataPtr: dataPtr,
            width: width,
            height: height,
            targetColor: targetColor,
            fillColor: fillColorValue,
            tolerance: toleranceValue,
            x: x,
            y: y
        )
        
        // Create a new image from the context
        guard let newCGImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: newCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// Performs an animated flood fill operation and provides updates as the fill progresses
    /// - Parameters:
    ///   - image: The source UIImage to modify
    ///   - point: The starting point for the flood fill
    ///   - fillColor: The color to fill with
    ///   - tolerance: The color tolerance (0-100) for matching similar colors
    ///   - updateInterval: Number of pixels to process before sending an update
    ///   - onProgress: Callback providing the current state of the fill operation
    ///   - onCompletion: Optional callback called when the fill is completely done
    static func animatedFloodFill(
        image: UIImage,
        at point: CGPoint,
        with fillColor: UIColor,
        tolerance: CGFloat = 10,
        updateInterval: Int = 1000,
        onProgress: @escaping (UIImage) -> Void,
        onCompletion: (() -> Void)? = nil
    ) {
        guard let cgImage = image.cgImage else {
            onCompletion?()
            return
        }
        
        // Create a correctly formatted bitmap context
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        // Create a new context with a known format
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            onCompletion?()
            return
        }
        
        // Draw the original image into the context
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: rect)
        
        // Convert point to integers for array indexing
        let x = Int(point.x)
        let y = Int(point.y)
        
        // Make sure point is within bounds
        guard x >= 0, y >= 0, x < width, y < height else {
            onCompletion?()
            return
        }
        
        // Get the image data
        guard let data = context.data else {
            onCompletion?()
            return
        }
        
        let dataPtr = data.bindMemory(to: UInt32.self, capacity: width * height)
        
        // Get the color at target point
        let targetColor = dataPtr[y * width + x]
        
        // Check if clicked on a black or very dark edge (we don't want to fill edges)
        if isBlackOrDarkEdge(targetColor) {
            onProgress(image)
            onCompletion?()
            return
        }
        
        // Create the fill color pixel
        let fillColorValue = createColorPixel(fillColor, bitmapInfo: bitmapInfo)
        
        // Scale tolerance from percentage to actual color range
        let toleranceValue = UInt32(tolerance * 2.55) // Scale from 0-100 to 0-255
        
        if colorDifference(targetColor, fillColorValue) <= toleranceValue {
            onProgress(image)
            onCompletion?()
            return
        }
        
        // Perform animated flood fill
        animatedFloodFillQueue(
            context: context,
            dataPtr: dataPtr,
            width: width,
            height: height,
            targetColor: targetColor,
            fillColor: fillColorValue,
            tolerance: toleranceValue,
            x: x,
            y: y,
            updateInterval: updateInterval,
            imageScale: image.scale,
            imageOrientation: image.imageOrientation,
            onProgress: onProgress,
            onCompletion: onCompletion
        )
    }
    
    /// Creates a pixel value with the correct byte order for the given UIColor and bitmap info
    private static func createColorPixel(_ color: UIColor, bitmapInfo: UInt32) -> UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = UInt32(red * 255.0)
        let g = UInt32(green * 255.0)
        let b = UInt32(blue * 255.0)
        let a = UInt32(alpha * 255.0)
        
        // Create a 1x1 context with the same format as our main context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
        
        // Set the context color and draw a point
        context?.setFillColor(color.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        
        // Extract the pixel value from this context
        if let data = context?.data {
            let dataPtr = data.bindMemory(to: UInt32.self, capacity: 1)
            return dataPtr[0]
        }
        
        // Fallback if context creation failed (shouldn't happen)
        return (a << 24) | (r << 16) | (g << 8) | b
    }
    
    /// Determines if a pixel color is black or very dark (an edge)
    /// - Parameter color: The pixel color value
    /// - Returns: True if the color is black or very dark
    private static func isBlackOrDarkEdge(_ color: UInt32) -> Bool {
        // Get total brightness regardless of byte order
        let byte1 = (color >> 0) & 0xFF
        let byte2 = (color >> 8) & 0xFF
        let byte3 = (color >> 16) & 0xFF
        
        // We don't care about alpha for brightness calculation
        let maxPossibleComponent = 255
        let componentSum = byte1 + byte2 + byte3
        
        // Calculate relative brightness (0-100%)
        let brightnessPercent = (CGFloat(componentSum) / CGFloat(maxPossibleComponent * 3)) * 100
        
        // Consider any color with less than 20% brightness as "dark"
        return brightnessPercent < 20
    }
    
    private static func colorDifference(_ color1: UInt32, _ color2: UInt32) -> UInt32 {
        // We can calculate difference regardless of component order
        // Extract all components
        let c1b1 = (color1 >> 0) & 0xFF
        let c1b2 = (color1 >> 8) & 0xFF
        let c1b3 = (color1 >> 16) & 0xFF
        
        let c2b1 = (color2 >> 0) & 0xFF
        let c2b2 = (color2 >> 8) & 0xFF
        let c2b3 = (color2 >> 16) & 0xFF
        
        // Calculate differences for each component
        let d1 = c1b1 > c2b1 ? c1b1 - c2b1 : c2b1 - c1b1
        let d2 = c1b2 > c2b2 ? c1b2 - c2b2 : c2b2 - c1b2
        let d3 = c1b3 > c2b3 ? c1b3 - c2b3 : c2b3 - c1b3
        
        // Use max difference as the metric
        return max(max(d1, d2), d3)
    }
    
    private static func floodFillQueue(dataPtr: UnsafeMutablePointer<UInt32>, width: Int, height: Int, targetColor: UInt32, fillColor: UInt32, tolerance: UInt32, x: Int, y: Int) {
        var queue = [(x, y)]
        var index = 0
        
        while index < queue.count {
            let (currentX, currentY) = queue[index]
            index += 1
            
            let position = currentY * width + currentX
            
            // Skip if already filled
            if dataPtr[position] == fillColor {
                continue
            }
            
            // Skip if it's a black edge - never fill black edges
            if isBlackOrDarkEdge(dataPtr[position]) {
                continue
            }
            
            // Skip if not similar enough to the target color
            if colorDifference(dataPtr[position], targetColor) > tolerance {
                continue
            }
            
            // Fill this pixel
            dataPtr[position] = fillColor
            
            // Add adjacent pixels to queue
            let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)] // 4-way connectivity
            for (dx, dy) in directions {
                let newX = currentX + dx
                let newY = currentY + dy
                
                // Check bounds
                if newX >= 0 && newX < width && newY >= 0 && newY < height {
                    // Add to queue if not a black edge, not already processed, and similar to target color
                    let newPosition = newY * width + newX
                    if !isBlackOrDarkEdge(dataPtr[newPosition]) &&
                       dataPtr[newPosition] != fillColor && 
                       colorDifference(dataPtr[newPosition], targetColor) <= tolerance {
                        queue.append((newX, newY))
                    }
                }
            }
        }
    }
    
    private static func animatedFloodFillQueue(
        context: CGContext,
        dataPtr: UnsafeMutablePointer<UInt32>,
        width: Int,
        height: Int,
        targetColor: UInt32,
        fillColor: UInt32,
        tolerance: UInt32,
        x: Int,
        y: Int,
        updateInterval: Int,
        imageScale: CGFloat,
        imageOrientation: UIImage.Orientation,
        onProgress: @escaping (UIImage) -> Void,
        onCompletion: (() -> Void)? = nil
    ) {
        // Create a queue for the flood fill algorithm - starting from initial point
        var queue = [(x, y)]
        
        // Create a set to track visited pixels to avoid duplicates
        var visited = Set<Int>()
        
        // Use DispatchQueue to avoid blocking the main thread
        DispatchQueue.global(qos: .userInteractive).async {
            // Initial update for instant feedback
            if let currentImage = context.makeImage() {
                let image = UIImage(cgImage: currentImage, scale: imageScale, orientation: imageOrientation)
                DispatchQueue.main.async {
                    onProgress(image)
                }
            }
            
            // Directions for 8-way connectivity for more natural spread
            let directions = [
                (0, 1), (1, 1), (1, 0), (1, -1),  // Right, down-right, down, down-left
                (0, -1), (-1, -1), (-1, 0), (-1, 1)  // Left, up-left, up, up-right
            ]
            
            while !queue.isEmpty {
                // Process a batch of pixels
                var newQueue: [(Int, Int)] = []
                let batchSize = min(updateInterval, queue.count)
                
                // Process the batch
                for i in 0..<batchSize {
                    let (currentX, currentY) = queue[i]
                    let position = currentY * width + currentX
                    
                    // Skip if already visited
                    if visited.contains(position) {
                        continue
                    }
                    
                    // Mark as visited
                    visited.insert(position)
                    
                    // Skip if already filled
                    if dataPtr[position] == fillColor {
                        continue
                    }
                    
                    // Skip if it's a black edge
                    if isBlackOrDarkEdge(dataPtr[position]) {
                        continue
                    }
                    
                    // Skip if not similar enough to the target color
                    if colorDifference(dataPtr[position], targetColor) > tolerance {
                        continue
                    }
                    
                    // Fill this pixel
                    dataPtr[position] = fillColor
                    
                    // Add adjacent pixels to the new queue with water-like spreading
                    for (dx, dy) in directions {
                        let newX = currentX + dx
                        let newY = currentY + dy
                        
                        // Check bounds
                        if newX >= 0 && newX < width && newY >= 0 && newY < height {
                            let newPosition = newY * width + newX
                            
                            // Add to queue if not already visited, not a black edge, and similar to target color
                            if !visited.contains(newPosition) &&
                               !isBlackOrDarkEdge(dataPtr[newPosition]) &&
                               dataPtr[newPosition] != fillColor && 
                               colorDifference(dataPtr[newPosition], targetColor) <= tolerance {
                                
                                // Prioritize edge pixels to create a more natural flow effect
                                // Edge pixels are pixels with at least one unfilled neighbor
                                var isEdge = false
                                for (edgeDx, edgeDy) in directions {
                                    let edgeX = newX + edgeDx
                                    let edgeY = newY + edgeDy
                                    
                                    if edgeX >= 0 && edgeX < width && edgeY >= 0 && edgeY < height {
                                        let edgePosition = edgeY * width + edgeX
                                        if dataPtr[edgePosition] != fillColor && 
                                           !isBlackOrDarkEdge(dataPtr[edgePosition]) &&
                                           colorDifference(dataPtr[edgePosition], targetColor) <= tolerance {
                                            isEdge = true
                                            break
                                        }
                                    }
                                }
                                
                                // If it's an edge pixel, add it to the front of the queue for priority
                                if isEdge {
                                    newQueue.insert((newX, newY), at: 0)
                                } else {
                                    newQueue.append((newX, newY))
                                }
                            }
                        }
                    }
                }
                
                // Remove the processed batch from the queue
                if batchSize <= queue.count {
                    queue.removeFirst(batchSize)
                } else {
                    queue.removeAll()
                }
                
                // Add new pixels to process
                queue.append(contentsOf: newQueue)
                
                // Create an image from the current state and update the UI
                if let currentImage = context.makeImage() {
                    let image = UIImage(cgImage: currentImage, scale: imageScale, orientation: imageOrientation)
                    DispatchQueue.main.async {
                        onProgress(image)
                    }
                }
                
                // Shorter delay to make the animation faster
                if !queue.isEmpty {
                    usleep(1000) // 1ms delay between updates
                }
            }
            
            // Final update to ensure we have the complete fill
            if let finalImage = context.makeImage() {
                let image = UIImage(cgImage: finalImage, scale: imageScale, orientation: imageOrientation)
                
                // Ensure we call completion only once and on the main thread
                DispatchQueue.main.async {
                    // Send the final image
                    onProgress(image)
                    
                    // Add a tiny delay to ensure UI has updated before notifying completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        // Notify that the fill is complete
                        onCompletion?()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    // Still notify completion even if final image creation fails
                    onCompletion?()
                }
            }
        }
    }
} 
