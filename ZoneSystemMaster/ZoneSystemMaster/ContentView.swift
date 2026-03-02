import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    ZStack {
                        LinearGradient(
                            colors: [.black, .gray, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            Text("Zone System Master")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()

                    // Zone Scale
                    VStack(alignment: .leading) {
                        Text("Zone Scale")
                            .font(.headline)
                        HStack(spacing: 2) {
                            ForEach(0...10, id: \.self) { zone in
                                Rectangle()
                                    .fill(Color(white: Double(zone) / 10.0))
                                    .frame(height: 40)
                                    .overlay(
                                        Text("\(zone)")
                                            .font(.caption2)
                                            .foregroundColor(zone < 5 ? .white : .black)
                                    )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)

                    // Features Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        FeatureCard(icon: "bubble.left.fill", title: "Chat with Ansel", color: .purple)
                        FeatureCard(icon: "camera.metering.center.weighted", title: "Exposure Meter", color: .orange)
                        FeatureCard(icon: "timer", title: "Darkroom Timer", color: .green)
                        FeatureCard(icon: "film.stack.fill", title: "Analog Archive", color: .blue)
                        FeatureCard(icon: "camera.filters", title: "Zone Editor", color: .red)
                        FeatureCard(icon: "printer.fill", title: "Instax Print", color: .pink)
                    }
                    .padding(.horizontal)

                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Ansel Adams Method")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Master the Zone System with AI-powered guidance. From exposure to development to printing, learn the craft of fine art black and white photography.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Zone System")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}
