import SwiftUI

struct ProfileEditView: View {
    @Binding var bio: String
    @Binding var gender: String // "male", "female", "other"
    @Binding var isPresented: Bool
    
    // Temporary state for editing before saving
    @State private var editedBio: String = ""
    @State private var editedGender: String = "other"
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color.Vibez.textSecondary)
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .vibezHeaderMedium()
                    
                    Spacer()
                    
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(Color.Vibez.electricBlue)
                    .fontWeight(.bold)
                }
                .padding()
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Gender Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IDENTITY")
                                .font(VibezTypography.caption)
                                .foregroundColor(Color.Vibez.textSecondary)
                                .padding(.leading, 4)
                            
                            GlassCard {
                                VStack(spacing: 0) {
                                    GenderOptionRow(title: "Male", selected: editedGender == "male") {
                                        editedGender = "male"
                                    }
                                    Divider().background(Color.white.opacity(0.1))
                                    GenderOptionRow(title: "Female", selected: editedGender == "female") {
                                        editedGender = "female"
                                    }
                                    Divider().background(Color.white.opacity(0.1))
                                    GenderOptionRow(title: "Other / Prefer not to say", selected: editedGender == "other") {
                                        editedGender = "other"
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Bio Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BIO")
                                .font(VibezTypography.caption)
                                .foregroundColor(Color.Vibez.textSecondary)
                                .padding(.leading, 4)
                            
                            GlassCard {
                                ZStack(alignment: .topLeading) {
                                    if editedBio.isEmpty {
                                        Text("Tell us about your vibe...")
                                            .foregroundColor(Color.Vibez.textSecondary)
                                            .padding(8)
                                    }
                                    
                                    TextEditor(text: $editedBio)
                                        .frame(minHeight: 100)
                                        .scrollContentBackground(.hidden)
                                        .foregroundColor(Color.Vibez.textPrimary)
                                        .font(VibezTypography.bodyMedium)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Text("Your bio is visible to other users. Keep it chill.")
                            .font(VibezTypography.caption)
                            .foregroundColor(Color.Vibez.textSecondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            editedBio = bio
            editedGender = gender.isEmpty ? "other" : gender
        }
    }
    
    private func saveChanges() {
        bio = editedBio
        gender = editedGender
        isPresented = false
    }
}

struct GenderOptionRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(Color.Vibez.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color.Vibez.electricBlue)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
    }
}

