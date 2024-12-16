import SwiftUI
import PhotosUI

struct ProfileCreationView: View {
    @Binding var isPresented: Bool
    @Binding var userName: String
    @Binding var profileImage: Image?
    @Binding var astrologySign: String
    
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var isAnimating = false
    
    private let astrologySigns = [
        ("♈️", "Aries", "March 21 - April 19"),
        ("♉️", "Taurus", "April 20 - May 20"),
        ("♊️", "Gemini", "May 21 - June 20"),
        ("♋️", "Cancer", "June 21 - July 22"),
        ("♌️", "Leo", "July 23 - August 22"),
        ("♍️", "Virgo", "August 23 - September 22"),
        ("♎️", "Libra", "September 23 - October 22"),
        ("♏️", "Scorpio", "October 23 - November 21"),
        ("♐️", "Sagittarius", "November 22 - December 21"),
        ("♑️", "Capricorn", "December 22 - January 19"),
        ("♒️", "Aquarius", "January 20 - February 18"),
        ("♓️", "Pisces", "February 19 - March 20")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Image Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Circle()
                                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                                )
                            
                            if let image = profileImage {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "person.crop.circle.fill.badge.plus")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 40))
                                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                    .animation(
                                        .easeInOut(duration: 20).repeatForever(autoreverses: false),
                                        value: isAnimating
                                    )
                            }
                        }
                        .onTapGesture {
                            showImagePicker = true
                        }
                        .onAppear {
                            isAnimating = true
                        }
                        
                        Text("Add Profile Picture")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.title3)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if userName.isEmpty {
                                        Text("Enter your name")
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 16)
                                    }
                                },
                                alignment: .leading
                            )
                    }
                    .padding(.horizontal)
                    
                    // Astrology Sign Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select Your Sign")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150), spacing: 16)
                        ], spacing: 16) {
                            ForEach(astrologySigns, id: \.1) { symbol, name, dates in
                                Button(action: {
                                    astrologySign = "\(symbol) \(name)"
                                }) {
                                    VStack(spacing: 8) {
                                        Text(symbol)
                                            .font(.system(size: 32))
                                        Text(name)
                                            .font(.headline)
                                        Text(dates)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(astrologySign.contains(name) ?
                                                  Color.accentColor.opacity(0.1) :
                                                    Color(.systemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                astrologySign.contains(name) ?
                                                Color.accentColor : Color.gray.opacity(0.2),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Do Later") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        isPresented = false
                    }
                    .font(.body.bold())
                    .foregroundColor(userName.isEmpty ? .gray : .accentColor)
                    .disabled(userName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .onChange(of: inputImage) { newImage in
            if let image = newImage {
                withAnimation {
                    profileImage = Image(uiImage: image)
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// Preview
struct ProfileCreationView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileCreationView(
            isPresented: .constant(true),
            userName: .constant(""),
            profileImage: .constant(nil),
            astrologySign: .constant("")
        )
        
        // Dark mode preview
        ProfileCreationView(
            isPresented: .constant(true),
            userName: .constant("John Doe"),
            profileImage: .constant(nil),
            astrologySign: .constant("♈️ Aries")
        )
        .preferredColorScheme(.dark)
    }
} 