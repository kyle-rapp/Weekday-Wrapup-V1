import SwiftUI
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

struct MediaCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Binding var capturedVideoURL: URL?
    @Binding var mediaError: String?
    @State private var showCamera = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Button(action: clearMedia) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
            } else if capturedVideoURL != nil {
                ZStack {
                    if let videoThumbnail {
                        Image(uiImage: videoThumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.black.opacity(0.82))
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Button(action: clearMedia) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                    
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Add a photo or upload a video")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 10) {
                            Button(action: { showCamera = true }) {
                                mediaButtonLabel("Camera", systemImage: "camera")
                            }
                            
                            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                                mediaButtonLabel("Photo", systemImage: "photo")
                            }

                            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                                mediaButtonLabel("Video", systemImage: "video")
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
        }
        .onChange(of: capturedImage) { _, image in
            if image != nil {
                capturedVideoURL = nil
                videoThumbnail = nil
            }
        }
        .onChange(of: selectedImageItem) { _, item in
            guard let item else { return }
            Task { await loadImage(from: item) }
        }
        .onChange(of: selectedVideoItem) { _, item in
            guard let item else { return }
            Task { await loadVideo(from: item) }
        }
    }

    private func mediaButtonLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minWidth: 74)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
    }

    private func clearMedia() {
        capturedImage = nil
        capturedVideoURL = nil
        videoThumbnail = nil
        mediaError = nil
        selectedImageItem = nil
        selectedVideoItem = nil
    }

    @MainActor
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                mediaError = "We couldn't read that photo. Try another one."
                return
            }
            capturedImage = image
            capturedVideoURL = nil
            videoThumbnail = nil
            mediaError = nil
        } catch {
            mediaError = "We couldn't load that photo. Try another one."
        }
    }

    @MainActor
    private func loadVideo(from item: PhotosPickerItem) async {
        do {
            let video = try await item.loadTransferable(type: PickedVideo.self)
            guard let url = video?.url else {
                mediaError = "We couldn't read that video. Try another one."
                return
            }
            let asset = AVURLAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            guard duration.isFinite, duration <= 12 else {
                capturedVideoURL = nil
                videoThumbnail = nil
                mediaError = "For now, videos need to be 12 seconds or less."
                return
            }
            capturedImage = nil
            capturedVideoURL = url
            videoThumbnail = try? Self.thumbnail(for: url)
            mediaError = nil
        } catch {
            mediaError = "We couldn't load that video. Try another one."
        }
    }

    private static func thumbnail(for url: URL) throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
}

private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("weekday-video-\(UUID().uuidString).\(ext)")
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideo(url: copy)
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var image: UIImage?
    
    @StateObject private var camera = CameraModel()
    
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack(spacing: 60) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    Button(action: camera.takePicture) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 65, height: 65)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 75, height: 75)
                        }
                    }
                    
                    Button(action: camera.flipCamera) {
                        Image(systemName: "camera.rotate")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
        .onChange(of: camera.photo) { newPhoto in
            if let photo = newPhoto {
                image = photo
                dismiss()
            }
        }
    }
}

class CameraModel: NSObject, ObservableObject {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var photo: UIImage?
    
    override init() {
        super.init()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    DispatchQueue.main.async {
                        self?.setUp()
                    }
                }
            }
        default:
            alert = true
            return
        }
    }
    
    func setUp() {
        do {
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video,
                                                      position: .back) else { return }
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func takePicture() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
    
    func flipCamera() {
        session.beginConfiguration()
        
        // Remove existing input
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        session.removeInput(currentInput)
        
        // Add new input
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video,
                                                  position: newPosition) else { return }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        session.commitConfiguration()
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                    didFinishProcessingPhoto photo: AVCapturePhoto,
                    error: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.photo = image
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        camera.preview = layer
        view.layer.addSublayer(layer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
} 