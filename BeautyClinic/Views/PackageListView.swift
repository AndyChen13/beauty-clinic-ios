import SwiftUI

struct PackageListView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var packages: [Package] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(packages, id: \.id) { package in
                    PackageRow(package: package)
                        .onTapGesture {
                            // Navigate to package detail
                        }
                }
            }
            .navigationTitle("服务套餐")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addPackage) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadPackages() }
        }
    }
    
    private func loadPackages() {
        isLoading = true
        Task {
            do {
                let data = try await supabaseClient?.from("packages").select()
                packages = data?.compactMap { Package(json: $0) } ?? []
            } catch {
                print("Error loading packages: \(error)")
            }
            isLoading = false
        }
    }
    
    private func addPackage() {
        // TODO: Present add package sheet
        print("Add package")
    }
}

struct PackageRow: View {
    let package: Package
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(package.categoryColor.opacity(0.2))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.headline)
                Text("\(package.categoryDisplay) • \(package.durationMinutes)分钟")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("¥\(String(format: "%.2f", package.price))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PackageListView()
}