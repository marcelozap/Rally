import SwiftUI

/// Minimal XIV-style bottom navigation — three destinations max.
enum RallyNavBarTab: Hashable {
    case locker
    case logbook
    case courts
}

struct RallyNavBar: View {
    @Binding var selection: RallyNavBarTab

    var body: some View {
        HStack(spacing: 0) {
            navItem(.locker, icon: "figure.tennis", label: "Locker")
            navItem(.logbook, icon: "book.pages.fill", label: "Logbook")
            navItem(.courts, icon: "globe.americas.fill", label: "Courts")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0.96),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
        }
        .contentShape(Rectangle())
    }

    private func navItem(_ tab: RallyNavBarTab, icon: String, label: String) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium, design: .rounded))
                    .tracking(0.3)
            }
            .foregroundStyle(selected ? Color.cyan : Color.white.opacity(0.42))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(selected ? Color.cyan.opacity(0.12) : Color.clear)
                    .padding(.horizontal, 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
