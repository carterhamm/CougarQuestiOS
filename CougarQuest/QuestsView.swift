//
//  QuestsView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/28/25.
//

import SwiftUI
import MapKit
import Kingfisher

struct QuestsView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var quests: [Quest] = []
    @Binding var selectedQuest: Quest?
    @ObservedObject private var morphState = MorphState.shared
    // Default to BYU campus if location not yet available
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.2529, longitude: -111.6498),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var hasCentered = false

    var body: some View {
        ZStack {
            // full-screen map, tracking user location, custom SF Symbol pin
            Map(
                coordinateRegion: $region,
                showsUserLocation: true,
                userTrackingMode: .constant(.none),
                annotationItems: quests.compactMap { quest -> AnnotatedQuest? in
                    guard let coord = parseCoordinate(from: quest.mapsLink) else { return nil }
                    return AnnotatedQuest(quest: quest, coordinate: coord)
                }
            ) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    let isCompleted = morphState.completedQuestTitles.contains(item.quest.title)
                    Button {
                        selectedQuest = item.quest
                        withAnimation(.easeInOut(duration: 0.6)) {
                            region.center = item.coordinate
                            region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        }
                    } label: {
                        ZStack {
                            // Border ring: CougarBlue for incomplete (action),
                            // white for completed (subtle). Glass-tinted for depth.
                            Color.clear
                                .frame(width: 50, height: 50)
                                .adaptiveGlassEffectTinted(
                                    color: isCompleted ? Color.white : Color.cougarBlue,
                                    in: Circle()
                                )
                            // Quest image
                            if let url = URL(string: item.quest.photoURL) {
                                KFImage(url)
                                    .loadDiskFileSynchronously()
                                    .cacheMemoryOnly()
                                    .fade(duration: 0)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            // .animation(.easeInOut(duration: 0.6), value: region) // Removed as per instruction
            .ignoresSafeArea()
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
                FirebaseService.shared.fetchQuests { fetched, _ in
                    quests = fetched ?? []
                    if let loc = locationManager.location, !hasCentered {
                        region.center = loc
                        hasCentered = true
                    }
                }
            }
            .onChange(of: selectedQuest?.id) { _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    if let quest = selectedQuest, let coord = parseCoordinate(from: quest.mapsLink) {
                        region.center = coord
                        region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    } else {
                        region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    }
                }
            }
        }
    }

    // Helper to extract coordinates from a Maps link
    private func parseCoordinate(from mapsLink: String) -> CLLocationCoordinate2D? {
        guard
            let url = URL(string: mapsLink),
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let coordValue = comps.queryItems?.first(where: { $0.name == "coordinate" })?.value
        else { return nil }
        let parts = coordValue.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1])
        else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

private struct AnnotatedQuest: Identifiable {
    let id: String
    let quest: Quest
    let coordinate: CLLocationCoordinate2D

    init(quest: Quest, coordinate: CLLocationCoordinate2D) {
        self.id = quest.id ?? UUID().uuidString
        self.quest = quest
        self.coordinate = coordinate
    }
}

struct QuestsView_Previews: PreviewProvider {
    static var previews: some View {
        QuestsView(selectedQuest: .constant(nil))
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.location = loc.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
