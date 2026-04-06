import SwiftUI

struct RemotesListSection: View {
    let refs: [GitRef]
    let limit: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onLoadMore: () -> Void

    private struct RemoteGroup: Identifiable {
        let remote: String
        let refs: [GitRef]
        var id: String { remote }
    }

    private var groups: [RemoteGroup] {
        var order: [String] = []
        var dict: [String: [GitRef]] = [:]
        for ref in refs.prefix(limit) {
            guard case .remoteBranch(let r) = ref.refType else { continue }
            if dict[r] == nil {
                order.append(r)
                dict[r] = []
            }
            dict[r]!.append(ref)
        }
        return order.map { RemoteGroup(remote: $0, refs: dict[$0]!) }
    }

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(groups) { group in
                    remoteHeader(group.remote)
                    ForEach(group.refs) { ref in
                        BranchCell(ref: ref)
                            .tag(ref.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 8))
                            .contextMenu {
                                Button("名前をコピー") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(ref.shortName, forType: .string)
                                }
                            }
                    }
                }
                if refs.count > limit {
                    Button {
                        onLoadMore()
                    } label: {
                        Text("さらに \(refs.count - limit) 件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            SectionToggleHeader(title: "REMOTES", isCollapsed: isCollapsed, onToggle: onToggle)
        }
    }

    @ViewBuilder
    private func remoteHeader(_ remote: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cloud")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(remote)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        // Absorb tap so clicking the header doesn't deselect the current branch
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

struct BranchListSection: View {
    let title: String
    let refs: [GitRef]
    let limit: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onLoadMore: () -> Void

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(Array(refs.prefix(limit))) { ref in
                    BranchCell(ref: ref)
                        .tag(ref.id)
                        .contextMenu {
                            Button("名前をコピー") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(ref.shortName, forType: .string)
                            }
                        }
                }
                if refs.count > limit {
                    Button {
                        onLoadMore()
                    } label: {
                        Text("さらに \(refs.count - limit) 件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            SectionToggleHeader(title: title, isCollapsed: isCollapsed, onToggle: onToggle)
        }
    }
}
