//
//  QuestView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/24/25.
//


import SwiftUI
import AVFoundation
import MapKit
import Kingfisher
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import AnyCodable

import UIKit

extension UIImage {
    func dominantColors(_ count: Int = 2) -> [UIColor] {
        let size = CGSize(width: count, height: 1)
        UIGraphicsBeginImageContext(size)
        self.draw(in: CGRect(origin: .zero, size: size))
        guard let context = UIGraphicsGetCurrentContext(),
              let data = context.data?.assumingMemoryBound(to: UInt8.self) else {
            UIGraphicsEndImageContext()
            return []
        }
        var colors: [UIColor] = []
        for i in 0..<count {
            let offset = i * 4
            let r = CGFloat(data[offset + 2]) / 255.0
            let g = CGFloat(data[offset + 1]) / 255.0
            let b = CGFloat(data[offset + 0]) / 255.0
            colors.append(UIColor(red: r, green: g, blue: b, alpha: 1))
        }
        UIGraphicsEndImageContext()
        return colors
    }
}

// Shape for selectively rounded corners
struct RoundedCorners: Shape {
    var topLeft: CGFloat = 0, topRight: CGFloat = 0, bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        // Ensure radii don't exceed dimensions
        let tl = min(min(self.topLeft, h/2), w/2)
        let tr = min(min(self.topRight, h/2), w/2)
        let bl = min(min(self.bottomLeft, h/2), w/2)
        let br = min(min(self.bottomRight, h/2), w/2)

        path.move(to: CGPoint(x: w/2, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct QuestView: View {
    @Binding var isQuestOpen: Bool
    @State private var region: MKCoordinateRegion
    @State private var isCompleted: Bool = false
    @Environment(\.colorScheme) var colorScheme

    @State private var showCameraPicker = false
    @State private var pickedImage: UIImage?

    @State private var gradientColors: [Color] = [.black, .clear]

    var quest: Quest

    init(quest: Quest, isQuestOpen: Binding<Bool>) {
        self.quest = quest
        self._isQuestOpen = isQuestOpen
        // Default to BYU Creamery location
        let defaultCenter = CLLocationCoordinate2D(latitude: 40.250106, longitude: -111.643463)
        // Attempt to extract latitude and longitude from the "ll" or "coordinate" query parameter
        var center = defaultCenter
        if let url = URL(string: quest.mapsLink),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Attempt to extract latitude and longitude from 'll' or 'coordinate' query parameters (case-insensitive)
            if let rawItem = components.queryItems?.first(where: { ["ll", "coordinate"].contains($0.name.lowercased()) }),
               let rawValue = rawItem.value {
                let decodedValue = rawValue.removingPercentEncoding ?? rawValue
                let parts = decodedValue.split(separator: ",")
                if parts.count == 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
        // Initialize the region state using the resolved center
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    private func uploadPhoto(_ image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let storageRef = Storage.storage().reference().child("\(uid)/\(quest.id ?? quest.title)/photo.png")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Upload error: \(error)")
                return
            }
            // After upload, mark quest complete
            Firestore.firestore().collection("users").document(uid)
                .updateData(["completedQuests": FieldValue.arrayUnion([quest.title])]) { error in
                    if error == nil {
                        // Calculate elapsed time and determine reward before incrementing points
                        let elapsed = Date().timeIntervalSince(quest.createdAt ?? Date())
                        let reward: Int64
                        if elapsed <= 12 * 3600 {
                            reward = 3   // 3 points within 12h
                        } else if elapsed <= 24 * 3600 {
                            reward = 2   // 2 points within 24h
                        } else {
                            reward = 1   // 1 point thereafter
                        }
                        Firestore.firestore().collection("users").document(uid)
                            .updateData(["points": FieldValue.increment(reward)]) { _ in }
                        withAnimation(.easeInOut) {
                            isCompleted = true
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            // Dismiss the quest view
                            isQuestOpen = false
                        }
                    }
                }
        }
    }

    struct ImagePicker: UIViewControllerRepresentable {
        @Environment(\.presentationMode) private var presentationMode
        var sourceType: UIImagePickerController.SourceType
        var completion: (UIImage) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = sourceType
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(self) }

        class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let parent: ImagePicker
            init(_ parent: ImagePicker) { self.parent = parent }
            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                if let image = info[.originalImage] as? UIImage {
                    parent.completion(image)
                }
                parent.presentationMode.wrappedValue.dismiss()
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    var body: some View {
        ZStack {
            // MARK: - Dynamic blurred background from quest image
            if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                KFImage(url)
                    .onSuccess { result in
                        let uiImage = result.image
                        // Sample many pixels for good color variety
                        let sampledColors = uiImage.dominantColors(100)
                        // Primary filter: high saturation, moderate brightness (avoid whites/grays)
                        var candidates = sampledColors.compactMap { uiColor -> (color: UIColor, saturation: CGFloat)? in
                            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                            guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
                                return nil
                            }
                            guard saturation > 0.5 && brightness > 0.15 && brightness < 0.85 else {
                                return nil
                            }
                            // Weight by saturation * (1 - brightness) to favor vivid darker tones
                            let weight = saturation * (1 - brightness)
                            return (color: uiColor, saturation: weight)
                        }
                        // If no candidates, fallback to just most saturated colors
                        if candidates.isEmpty {
                            candidates = sampledColors.compactMap { uiColor -> (color: UIColor, saturation: CGFloat)? in
                                var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                                guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
                                    return nil
                                }
                                return (color: uiColor, saturation: saturation)
                            }
                        }
                        // Sort by saturation descending and pick top two
                        let chosenUI = candidates
                            .sorted { $0.saturation > $1.saturation }
                            .prefix(2)
                            .map { $0.color }
                        // Final fallback: if still fewer than 2, use first two sampled
                        let finalColors = chosenUI.count >= 2
                            ? chosenUI
                            : sampledColors.prefix(2).map { $0 }
                        gradientColors = finalColors.map { Color($0) }
                    }
                    .placeholder { Color.gray.opacity(0.3) }
                    .cancelOnDisappear(true)
                    .loadDiskFileSynchronously()
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .blur(radius: 50)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            }
            ScrollView(showsIndicators: false) {
                ZStack {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack(alignment: .bottom) {
                            if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                                KFImage(url)
                                    .placeholder {
                                        Color.gray.opacity(0.3)
                                    }
                                    .cancelOnDisappear(true)
                                    .loadDiskFileSynchronously()
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: UIScreen.main.bounds.width, height: 360)
                                    .clipped()
                                    // Strong blur overlay on header image
                                    .overlay(
                                        KFImage(url)
                                            .cancelOnDisappear(true)
                                            .loadDiskFileSynchronously()
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: UIScreen.main.bounds.width, height: 360)
                                            .clipped()
                                            .mask(
                                                LinearGradient(
                                                    gradient: Gradient(stops: [
                                                        .init(color: Color.white.opacity(1), location: 1.0),
                                                        .init(color: Color.white.opacity(0), location: 0.6)
                                                    ]),
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )
                                    )
                            } else {
                                Color.gray.opacity(0.3)
                                    .frame(width: UIScreen.main.bounds.width, height: 360)
                            }
                            VStack(alignment: .center, spacing: 8) {
                                Text(quest.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Text(quest.description)
                            .font(.body)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width - 25, alignment: .center)
                            .adaptiveGlassEffect(
                                in: RoundedRectangle(cornerRadius: 20),
                                strokeColor: colorScheme == .dark ? Color(UIColor.darkGray) : Color(UIColor.lightGray),
                                strokeWidth: 1.2
                            )
                            .padding(.horizontal)
                        
                        // MARK: Embedded Map
                        ZStack(alignment: .bottom) {
                            // Address card overlays bottom of map
                            HStack {
                                Spacer()
                                VStack(alignment: .center, spacing: 4) {
                                    Text(quest.address)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .padding(.horizontal)
                                }
                                .padding(EdgeInsets(top: 34, leading: 0, bottom: 8, trailing: 0))
                                .frame(width: UIScreen.main.bounds.width - 25)
                                .frame(minHeight: 80)
                                .adaptiveGlassEffect(
                                    in: RoundedCorners(topLeft: 0, topRight: 0, bottomLeft: 20, bottomRight: 20),
                                    strokeColor: colorScheme == .dark ? Color(UIColor.darkGray) : Color(UIColor.lightGray),
                                    strokeWidth: 1.2
                                )
                                .contextMenu {
                                    Button("Copy Address") {
                                        UIPasteboard.general.string = quest.address
                                    }
                                }
                                Spacer()
                            }
                            .offset(y: 50) // adjust vertical overlap as needed

                            Map(coordinateRegion: $region, interactionModes: .pitch)
                                .frame(width: UIScreen.main.bounds.width - 25, height: 200)
                                .cornerRadius(20)
                                .onTapGesture {
                                    guard let url = URL(string: quest.mapsLink),
                                          UIApplication.shared.canOpenURL(url)
                                    else { return }
                                    UIApplication.shared.open(url)
                                }
                        }
                        .padding(.horizontal, 0)
                        
                        // Extra vertical spacing for scrolling
                        Color.clear
                            .frame(height: 250)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .overlay(
                BlurView(style: .systemUltraThinMaterial)
                    .frame(height: 100)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                    )
                    .ignoresSafeArea(edges: .top),
                alignment: .top
            )
            .onAppear {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                Firestore.firestore().collection("users").document(uid)
                    .getDocument { snapshot, _ in
                        if let array = snapshot?.data()?["completedQuests"] as? [String] {
                            isCompleted = array.contains(quest.title)
                        }
                    }
            }

        }
        .onAppear {
            isQuestOpen = true
        }
        .onDisappear {
            isQuestOpen = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let id = quest.id, let url = CougarQuestLink.url(forQuestId: id) {
                    ShareLink(
                        item: url,
                        subject: Text(quest.title),
                        message: Text("Check out this CougarQuest: \(quest.title)\n\(quest.address)")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                Circle().fill(Color.black.opacity(0.35))
                            )
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct QuestView_Previews: PreviewProvider {
    @State static var isQuestOpen = false
    static var previews: some View {
        QuestView(
            quest: Quest(
                id: "1",
                title: "Sample Quest",
                address: "123 Main St",
                description: "This is a sample quest description for preview purposes.",
                mapsLink: "",
                plusCode: "",
                photoURL: "",
                createdAt: Date(),
                completedAt: nil
            ),
            isQuestOpen: $isQuestOpen
        )
    }
}
