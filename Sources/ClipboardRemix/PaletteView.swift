import SwiftUI
import ClipboardCore

struct PaletteView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search copied text…", text: $model.query)
                    .textFieldStyle(.plain).font(.title3).focused($searchFocused)
                    .accessibilityLabel("Search clipboard history")
                Picker("Filter", selection: $model.filter) {
                    ForEach(ClipFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 190)
            }.padding(16)
            Divider()
            HStack(spacing: 0) {
                history.frame(width: 290)
                Divider()
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            if let status = model.status {
                HStack { Text(status).font(.caption).foregroundStyle(.orange); Spacer(); Button("Dismiss") { model.status = nil } }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                Divider()
            }
            HStack(spacing: 12) {
                Menu {
                    Button(model.paused ? "Resume Capture" : "Pause Capture") { model.paused.toggle() }
                    Button("Delete Selected", action: model.deleteSelected).disabled(model.selected == nil)
                    Button("Clear History…", action: model.clear)
                    Divider()
                    Text("Local only · 500 items · 500 MB images")
                    Button("Open Storage Folder") { NSWorkspace.shared.open(model.store.root) }
                    Divider()
                    Button("Quit Clipboard Remix") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }.menuStyle(.borderlessButton).frame(width: 24)
                Text(model.paused ? "Capture paused" : "\(model.items.count) saved")
                    .foregroundStyle(model.paused ? .orange : .secondary)
                Spacer()
                Text("↑↓ move   ⌘1–9 copy   esc close").foregroundStyle(.secondary)
                Button(model.isCopying ? "Copying…" : "Copy ↩") { model.copy() }
                    .buttonStyle(.borderedProminent).disabled(model.selected == nil || model.isCopying)
            }.font(.caption).padding(12)
        }
        .frame(minWidth: 740, minHeight: 460)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
        .onChange(of: model.openGeneration) { _, _ in searchFocused = true }
    }
    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    let rows = model.visible
                    if rows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.items.isEmpty ? "Your copies start here" : "No matches").font(.headline)
                            Text(model.items.isEmpty ? "Copy text or a screenshot while Clipboard Remix is running." : "Try another search or filter. Images aren't searched by their contents.")
                                .foregroundStyle(.secondary)
                        }.padding(16)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                        if index == 0 || !Calendar.current.isDate(item.created, inSameDayAs: rows[index - 1].created) {
                            Text(dayLabel(item.created)).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.top, 10)
                        }
                        Button { model.selectedID = item.id } label: {
                            HStack(spacing: 9) {
                                if item.kind == .image {
                                    ClipImage(item: item, store: model.store, thumbnail: true).frame(width: 42, height: 34)
                                } else {
                                    Image(systemName: "text.alignleft").foregroundStyle(.secondary).frame(width: 42, height: 34)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.system(size: 12)).lineLimit(2).multilineTextAlignment(.leading)
                                    Text(item.created, style: .time).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if index < 9 { Text("⌘\(index + 1)").font(.caption2).foregroundStyle(.secondary) }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(model.selectedID == item.id ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(model.selectedID == item.id ? Color.accentColor : .clear, lineWidth: 1))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).id(item.id)
                    }
                }.padding(8)
            }.onChange(of: model.selectedID) { _, id in if let id { proxy.scrollTo(id) } }
        }
    }
    @ViewBuilder private var preview: some View {
        if let item = model.selected {
            VStack(alignment: .leading, spacing: 12) {
                if let text = item.text {
                    ScrollView {
                        Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading).padding(14)
                    }.background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ClipImage(item: item, store: model.store, thumbnail: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12).background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                HStack {
                    Text(item.kind == .image ? "\(item.width) × \(item.height)" : "Plain text")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.bytes), countStyle: .file))
                }.font(.caption).foregroundStyle(.secondary)
                Text(item.created.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
            }.padding(16).id(item.id)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clipboard").font(.system(size: 38)).foregroundStyle(.tertiary)
                Text("Select a copy to preview").foregroundStyle(.secondary)
                Text("Copy it back, then paste with ⌘V.").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct ClipImage: View {
    let item: HistoryItem
    let store: HistoryStore
    let thumbnail: Bool
    @StateObject private var loader = ImageLoader()
    var body: some View {
        Group {
            if let image = loader.image { Image(nsImage: image).resizable().scaledToFit() }
            else if loader.failed { Image(systemName: "photo.badge.exclamationmark").accessibilityLabel("Image unavailable") }
            else { ProgressView().controlSize(.small) }
        }.task(id: item.id) {
            loader.image = nil; loader.failed = false
            do {
                let data: Data
                if thumbnail { data = try await store.imageData(for: item, thumbnail: true) }
                else { data = try await store.previewData(for: item) }
                guard !Task.isCancelled else { return }
                loader.image = NSImage(data: data); loader.failed = loader.image == nil
            } catch { loader.failed = true }
        }
    }
}

@MainActor private final class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var failed = false
}
