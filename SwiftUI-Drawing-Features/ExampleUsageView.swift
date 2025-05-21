//
//  ExampleUsageView.swift
//  FloodFill-Test
//
//  Created by Saksham Shrey on 03/05/25.
//

import SwiftUI
import PhotosUI

struct ExampleUsageView: View {
    @State private var inputImage: UIImage? = UIImage(named: "testImage")
    @State private var processedImage: UIImage?
    @State private var isShowingFloodFill = false
    @State private var isShowingDrawingConverter = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack {
            Text("Image Processing Features")
                .font(.largeTitle)
                .padding()
            
            if let image = processedImage ?? inputImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.black.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .overlay(
                        Text("No Image Selected")
                            .foregroundColor(.gray)
                    )
                    .padding()
            }
            
            // Photo selection button
            Button(action: {
                isShowingPhotoPicker = true
            }) {
                Label("Select Image", systemImage: "photo")
                    .font(.headline)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)
            
            // Features section
            VStack(spacing: 20) {
                Text("Choose a Feature")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    // Flood Fill button
                    Button(action: {
                        isShowingFloodFill = true
                    }) {
                        VStack {
                            Image(systemName: "paintbrush.fill")
                                .font(.largeTitle)
                                .foregroundColor(.purple)
                            
                            Text("Flood Fill")
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(inputImage == nil)
                    
                    // Stencil Creator button
                    Button(action: {
                        isShowingDrawingConverter = true
                    }) {
                        VStack {
                            Image(systemName: "pencil.and.outline")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            
                            Text("Stencil")
                                .font(.subheadline)
                            
                            Text("Creator")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(inputImage == nil)
                }
            }
            .padding()
            
            if processedImage != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Image processed and ready for coloring!")
                        .foregroundColor(.green)
                        .font(.headline)
                }
                .padding()
            }
            
            Spacer()
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { oldValue, newValue in
            if let newValue = newValue {
                loadImage(from: newValue)
            }
        }
        .sheet(isPresented: $isShowingFloodFill, onDismiss: {
            selectedItem = nil
        }) {
            FloodFillView(inputImage: inputImage) { savedImage in
                self.processedImage = savedImage
                self.isShowingFloodFill = false
            }
        }
        .sheet(isPresented: $isShowingDrawingConverter, onDismiss: {
            selectedItem = nil
        }) {
            DrawingImageView(inputImage: inputImage) { savedImage in
                self.processedImage = savedImage
                self.isShowingDrawingConverter = false
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.inputImage = image
                        self.processedImage = nil // Reset processed image when new input is loaded
                    }
                }
            case .failure:
                print("Failed to load image from Photos")
            }
        }
    }
}

#Preview {
    ExampleUsageView()
} 
