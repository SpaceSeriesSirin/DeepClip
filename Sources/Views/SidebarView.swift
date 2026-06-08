import SwiftUI

/// Left-hand category tree: All / Pinned, content types, and URL sub-domains.
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    /// Domain folders default to expanded so users see captured sites at a glance.
    @State private var domainsExpanded = true

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { appState.selection },
            set: { newValue in
                guard let value = newValue else { return }
                appState.selection = value
                appState.runSearch()
            }
        )
    }

    var body: some View {
        List(selection: selectionBinding) {
            Section {
                row(.all, count: appState.totalCount)
                row(.pinned, count: appState.pinnedCount)
            }

            Section("Categories") {
                ForEach(ContentType.allCases) { type in
                    if type == .url, !appState.domains.isEmpty {
                        // The URL row carries its own disclosure chevron; clicking
                        // it expands/collapses the per-domain sub-folders directly
                        // beneath the URL category instead of using a separate
                        // "Domains" group.
                        urlRow(count: appState.typeCounts[type.rawValue] ?? 0)

                        if domainsExpanded {
                            ForEach(appState.domains, id: \.self) { domain in
                                domainRow(domain)
                            }
                        }
                    } else {
                        row(.type(type), count: appState.typeCounts[type.rawValue] ?? 0)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    private func row(_ selection: SidebarSelection, count: Int?) -> some View {
        Label {
            HStack {
                Text(selection.title).lineLimit(1)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        } icon: {
            Image(systemName: selection.systemImage)
                .foregroundStyle(color(for: selection))
        }
        .tag(selection)
    }

    /// The URL category row with a leading disclosure chevron that toggles the
    /// per-domain sub-folders shown directly beneath it.
    private func urlRow(count: Int) -> some View {
        let selection = SidebarSelection.type(.url)
        return Label {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        domainsExpanded.toggle()
                    }
                } label: {
                    Image(systemName: domainsExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Text(selection.title).lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        } icon: {
            Image(systemName: selection.systemImage)
                .foregroundStyle(color(for: selection))
        }
        .tag(selection)
    }

    private func domainRow(_ domain: String) -> some View {
        Label {
            Text(domain).lineLimit(1)
        } icon: {
            Image(systemName: "globe").foregroundStyle(.blue)
        }
        .font(.callout)
        .padding(.leading, 18)
        .tag(SidebarSelection.domain(domain))
    }

    private func color(for selection: SidebarSelection) -> Color {
        switch selection {
        case .all: return .primary
        case .pinned: return .yellow
        case .type(let t): return .forContentType(t)
        case .domain: return .blue
        }
    }
}
