//
//  ClipQuestPreview.swift
//  Clip
//
//  The single screen the App Clip ever shows: photo banner, title,
//  address, description, Navigate button, Get-the-app CTA.
//

import SwiftUI
import Kingfisher

struct ClipQuestPreview: View {
    let quest: ClipQuest
    let onGetApp: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroPhoto
                VStack(alignment: .leading, spacing: 14) {
                    Text(quest.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if !quest.address.isEmpty {
                        Label(quest.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    if !quest.description.isEmpty {
                        Text(quest.description)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.85))
                    }
                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let url = URL(string: quest.mapsLink), !quest.mapsLink.isEmpty {
                    Link(destination: url) {
                        Label("Navigate", systemImage: "location.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                Button(action: onGetApp) {
                    Label("Get the full CougarQuest app", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(.thinMaterial)
        }
    }

    @ViewBuilder
    private var heroPhoto: some View {
        ZStack(alignment: .bottom) {
            if let url = URL(string: quest.photoURL), !quest.photoURL.isEmpty {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
            } else {
                Color.gray.opacity(0.3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
            }
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 120)
        }
    }
}
