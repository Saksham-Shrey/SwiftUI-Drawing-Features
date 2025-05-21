//
//  FloodFillView.swift
//  FloodFill-Test
//
//  Created by Saksham Shrey on 03/05/25.
//

import SwiftUI
import PhotosUI

struct FloodFillView: View {
    @StateObject var viewModel: FloodFillViewModel = FloodFillViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Input image and save callback
    var inputImage: UIImage?
    var onSave: ((UIImage) -> Void)?
    
    // Available colors for filling
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    
    var body: some View {
        VStack {
            if let uiImage = viewModel.currentImage ?? inputImage ?? UIImage(named: "testImage") {
                GeometryReader { geometry in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 3)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    // Only proceed if not already animating - use a direct access rather than going through the published property
                                    // which might have some delay in updates
                                    let imageSize = geometry.size
                                    let touchPoint = value.location
                                    
                                    // Only proceed if the touch is within the image bounds
                                    if touchPoint.x >= 0 && touchPoint.x <= imageSize.width &&
                                       touchPoint.y >= 0 && touchPoint.y <= imageSize.height {
                                        // Apply haptic feedback to indicate start of fill
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.prepare() // Prepare the generator for lower latency
                                        generator.impactOccurred()
                                        
                                        // Start the fill operation
                                        viewModel.applyFloodFill(
                                            at: touchPoint,
                                            imageFrame: geometry.frame(in: .local),
                                            image: uiImage,
                                            with: viewModel.selectedColor,
                                            tolerance: viewModel.tolerance
                                        )
                                    }
                                }
                        )
                        .overlay(
                            // Show a ripple animation effect when filling
                            ZStack {
                                if viewModel.isAnimatingFill {
                                    // Water ripple effects
                                    ForEach(0..<5) { i in
                                        Circle()
                                            .stroke(viewModel.selectedColor.opacity(0.5), lineWidth: 2)
                                            .frame(width: 10, height: 10)
                                            .scaleEffect(viewModel.isAnimatingFill ? 3 + CGFloat(i) * 0.5 : 0.5)
                                            .opacity(viewModel.isAnimatingFill ? 0 : 0.8)
                                            .animation(
                                                Animation.easeOut(duration: 0.3)
                                                    .repeatForever(autoreverses: false)
                                                    .delay(0.05 * Double(i)),
                                                value: viewModel.isAnimatingFill
                                            )
                                    }
                                }
                            }
                        )
                }
                .onAppear {
                    // Initialize with the input image if provided
                    if let inputImage = inputImage {
                        // Always initialize with the input image when it's available
                        // This ensures history is reset when a new image is supplied
                        viewModel.initializeWithImage(inputImage)
                    } 
                    // Otherwise initialize with the test image if no image is set yet
                    else if viewModel.currentImage == nil, let testImage = UIImage(named: "testImage") {
                        viewModel.initializeWithImage(testImage)
                    }
                }
            } else {
                Text("Image not found")
                    .foregroundColor(.red)
                    .font(.headline)
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    viewModel.resetImage()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .top, endPoint: .bottom))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Button(action: {
                    viewModel.undo()
                }) {
                    Label("", systemImage: "arrow.uturn.backward")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.canUndo ?
                            LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.gray.opacity(0.8), Color.gray], startPoint: .top, endPoint: .bottom)
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(!viewModel.canUndo)
                
                Button(action: {
                    viewModel.redo()
                }) {
                    Label("", systemImage: "arrow.uturn.forward")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.canRedo ?
                            LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.gray.opacity(0.8), Color.gray], startPoint: .top, endPoint: .bottom)
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(!viewModel.canRedo)
                
                Button(action: {
                    viewModel.saveImage()
                    if let savedImage = viewModel.savedImage {
                        onSave?(savedImage)
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(LinearGradient(colors: [Color.green.opacity(0.8), Color.green], startPoint: .top, endPoint: .bottom))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isAnimatingFill)
            }
            .padding()
            
            // Tolerance slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Tolerance: \(Int(viewModel.tolerance))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.tolerance, in: 0...100, step: 1)
                        .padding(.horizontal, 8)
                    
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Color selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .top, endPoint: .bottom))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(color == viewModel.selectedColor ? Color.white : Color.clear, lineWidth: 3)
                            )
                            .shadow(color: color == viewModel.selectedColor ? .black.opacity(0.5) : .clear, radius: 3)
                            .scaleEffect(color == viewModel.selectedColor ? 1.2 : 1.0)
                            .animation(.spring, value: viewModel.selectedColor)
                            .onTapGesture {
                                viewModel.selectedColor = color
                                // Provide haptic feedback on color selection
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                    }
                    
                    // Add custom color picker
                    ColorPicker("", selection: $viewModel.selectedColor)
                        .labelsHidden()
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.white)
                                .overlay(
                                    Circle()
                                        .strokeBorder(LinearGradient(colors: [.red, .green, .blue, .yellow, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                )
                        )
                        .overlay(
                            Image(systemName: "eyedropper")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        )
                        .scaleEffect(!colors.contains(viewModel.selectedColor) ? 1.2 : 1.0)
                        .animation(.spring, value: !colors.contains(viewModel.selectedColor))
                        .onChange(of: viewModel.selectedColor) { _,_ in
                            // Provide haptic feedback on color selection
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                        .padding(.horizontal, 5)
                    
                    // Custom color preview (shows current custom color)
                    if !colors.contains(viewModel.selectedColor) {
                        Circle()
                            .fill(viewModel.selectedColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                }
                .padding()
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .padding([.horizontal, .bottom])
        }
        .background(Color(.systemGroupedBackground))
    }
}


#Preview {
    FloodFillView()
}
