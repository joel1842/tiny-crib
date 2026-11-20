import SwiftUI

struct KeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Keycap(label: key)
            Text(action)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.dim)
        }
    }
}
