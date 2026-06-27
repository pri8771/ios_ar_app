//
//  ObjectPaletteView.swift
//  Shadow Lens
//
//  Horizontal palette to choose which proxy object the next tap will place.
//  Accessible buttons with clear selection state.
//

import SwiftUI

struct ObjectPaletteView: View {
    @Binding var selectedKind: BlockerKind

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BlockerKind.allCases) { kind in
                    Button {
                        selectedKind = kind
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.systemImage)
                                .font(.title3)
                            Text(kind.displayName)
                                .font(.caption2)
                        }
                        .frame(width: 64, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedKind == kind
                                      ? BlockerStyle.swiftUIColor(for: kind).opacity(0.9)
                                      : Color.secondary.opacity(0.2)))
                        .foregroundStyle(selectedKind == kind ? .white : .primary)
                    }
                    .accessibilityLabel("\(kind.displayName)\(selectedKind == kind ? ", selected" : "")")
                    .accessibilityHint("Sets the object placed on the next tap")
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State var kind: BlockerKind = .pole
    var body: some View { ObjectPaletteView(selectedKind: $kind).padding() }
}
