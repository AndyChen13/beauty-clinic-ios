import SwiftUI

struct AvatarView: View {
    let name: String
    
    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 48, height: 48)
            .overlay(
                Text(name.prefix(1))
                    .font(.title2.weight(.bold))
                    .foregroundColor(.blue)
            )
    }
}

extension AvatarView {
    init() {
        self.name = ""
    }
}