//
//  AddQuestView.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/27/25.
//

import SwiftUI
import UIKit
import Foundation

struct AddQuestView: View {
  @Environment(\.presentationMode) private var presentationMode

  @State private var title       = ""
  @State private var address     = ""
  @State private var mapsLink    = ""
  @State private var plusCode = ""
  @State private var description = ""
  @State private var image: UIImage?

  @State private var showingPicker      = false
  @State private var pickerSource: ImagePicker.Source = .library

  var body: some View {
    Form {
      Section("Details") {
        TextField("Title",   text: $title)
        TextField("Address", text: $address)
        TextField("Maps link", text: $mapsLink)
        TextField(
          "Plus Code (e.g. 7FG9+V6 Provo, UT)",
          text: $plusCode
        )
        TextEditor(text: $description)
          .frame(height: 100)
      }

      Section("Photo") {
        if let img = image {
          Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(height: 150)
        } else {
          HStack {
            Button("Library") {
              pickerSource = .library
              showingPicker = true
            }
            Spacer()
            Button("Camera") {
              pickerSource = .camera
              showingPicker = true
            }
          }
        }
      }

      Section {
        Button {
          saveQuest()
        } label: {
          HStack {
            Spacer()
            Text("Save Quest")
            Spacer()
          }
        }
      }
      
      // .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
      //           || address.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    .navigationTitle("New Quest")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          Button("Send New Quest Notification") {
            sendNewQuestNotification()
          }
        } label: {
          Image(systemName: "app.badge")
        }
      }
    }
    .sheet(isPresented: $showingPicker) {
      ImagePicker(source: pickerSource, image: $image)
    }
  }

  private func saveQuest() {
    let q = Quest(
      id: nil,
      title: title,
      address: address,
      description: description,
      mapsLink: mapsLink,
      plusCode: plusCode,
      photoURL: "",
      createdAt: Date(),
      completedAt: nil
    )
    FirebaseService.shared.addQuest(q, photo: image) { error in
      if error == nil {
        presentationMode.wrappedValue.dismiss()
      }
    }
  }

  private func sendNewQuestNotification() {
    let title = "New quests available"
    let body = "Get a head start on new quests!"
    // Stubbed notification service; ensure it only targets signed-in users
    NotificationService.shared.sendNotificationToSignedInUsers(title: title, body: body)
  }
}

struct ImagePicker: UIViewControllerRepresentable {
    enum Source { case library, camera }
    let source: Source
    var cameraDevice: UIImagePickerController.CameraDevice = .front
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if source == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.modalPresentationStyle = .fullScreen
            if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
                picker.cameraDevice = cameraDevice
            }
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                // only save to roll if coming from camera
                if parent.source == .camera {
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    AddQuestView()
}
