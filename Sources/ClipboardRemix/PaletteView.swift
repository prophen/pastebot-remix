import SwiftUI
import ClipboardCore

struct PaletteView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @AppStorage("paletteTextSize") private var textSize = "large"
    private var textScale: CGFloat { textSize == "extraLarge" ? 1.5 : textSize == "standard" ? 1 : 1.25 }
    private func font(_ points: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: points * textScale, weight: weight, design: design)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search copied text…", text: $model.query)
                    .textFieldStyle(.plain).font(font(15)).focused($searchFocused)
                    .accessibilityLabel("Search clipboard history")
                Picker("Filter", selection: $model.filter) {
                    ForEach(ClipFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 190)
            }.padding(16)
            Divider()
            HStack(spacing: 0) {
                history.frame(width: 290 + 80 * (textScale - 1))
                Divider()
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            if let status = model.status {
                HStack { Text(status).font(font(11)).foregroundStyle(.orange); Spacer(); Button("Dismiss") { model.status = nil } }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                Divider()
            }
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 12) {
                Menu {
                    if model.paused { Button("Resume Capture", action: model.resumeCapture) }
                    Button("Pause for 15 Minutes", action: model.pauseFor15Minutes)
                    Button("Pause Indefinitely", action: model.pauseIndefinitely)
                    LoginMenu(controller: model.login)
                    Divider()
                    Picker("Text Size", selection: $textSize) {
                        Text("Standard (100%)").tag("standard")
                        Text("Large (125%)").tag("large")
                        Text("Extra Large (150%)").tag("extraLarge")
                    }

                    Divider()
                    Button("Delete Selected", action: model.deleteSelected).disabled(model.selected == nil)
                    Button("Clear History…", action: model.clear)
                    Divider()
                    Text("Local only · 500 items · 500 MB images")
                    Button("Open Storage Folder") { NSWorkspace.shared.open(model.store.root) }
                    Divider()
                    Button("Quit Clipboard Remix") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                        .font(font(13))
                        .padding(.trailing, 8)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 40, height: 24)
                .accessibilityLabel("Clipboard controls")
                Text(model.paused ? model.pauseDescription : "\(model.items.count) saved")
                    .foregroundStyle(model.paused ? .orange : .secondary)
                Spacer()
                Button(model.isCopying ? "Copying…" : "Copy ↩") { model.copy() }
                    .buttonStyle(.borderedProminent).disabled(model.selected == nil || model.isCopying)
              }
              Text(model.pasteDestinationName.map { "Paste → \($0)   ↑↓ preview   esc close" } ?? "Focus a destination first   ↑↓ preview")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.font(font(11)).padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .font(font(13))
        .background(.regularMaterial)
        .overlay(alignment: .topTrailing) {
            if let feedback = model.feedback {
                Text(feedback)
                    .font(font(11, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.secondary.opacity(0.3)))
                    .padding(.top, 62).padding(.trailing, 16)
                    .allowsHitTesting(false)
                    .accessibilityLabel(feedback)
            }
        }
        .onAppear { searchFocused = true }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in model.login.refresh() }
        .onChange(of: model.openGeneration) { _, _ in searchFocused = true }
    }
    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    let rows = model.visible
                    if rows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.items.isEmpty ? "Your copies start here" : "No matches").font(font(13, weight: .semibold))
                            Text(model.items.isEmpty ? "Copy text or a screenshot while Clipboard Remix is running." : "Try another search or filter. Images aren't searched by their contents.")
                                .foregroundStyle(.secondary)
                        }.padding(16)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                        if index == 0 || item.isPinned != rows[index - 1].isPinned || (!item.isPinned && !Calendar.current.isDate(item.created, inSameDayAs: rows[index - 1].created)) {
                            Text(item.isPinned ? "Pinned" : dayLabel(item.created)).font(font(11, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.top, 10)
                        }
                            HStack(spacing: 9) {
                                if item.kind == .image {
                                    ClipImage(item: item, store: model.store, thumbnail: true).frame(width: 42, height: 34)
                                } else {
                                    Image(systemName: "text.alignleft").foregroundStyle(.secondary).frame(width: 42, height: 34)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(font(12)).lineLimit(2).multilineTextAlignment(.leading)
                                    Text(item.created, style: .time).font(font(10)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if item.isPinned { Image(systemName: "pin.fill").foregroundStyle(.secondary).accessibilityLabel("Pinned favorite") }
                                if index < 9 { Text("⌘\(index + 1)").font(font(10)).foregroundStyle(.secondary) }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(model.selectedID == item.id ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(model.selectedID == item.id ? Color.accentColor : .clear, lineWidth: 1))
                                .contentShape(Rectangle())
                        .gesture(
                            TapGesture(count: 2).exclusively(before: TapGesture(count: 1))
                                .onEnded { gesture in
                                    guard !model.isCopying else { return }
                                    model.selectedID = item.id
                                    switch gesture {
                                    case .first: model.copy(item, dismissAfterCopy: false)
                                    case .second: model.pasteItem?(item)
                                    }
                                }
                        )
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.selectedID = item.id; model.pasteItem?(item) }
                        .accessibilityAction(named: Text("Copy Only")) { model.copy(item, dismissAfterCopy: false) }
                        .id(item.id)
                        .disabled(model.isCopying)
                        .help("Click to paste. Double-click to copy only. The palette stays open. Use arrow keys to preview.")
                        .contextMenu {
                            Button(item.isPinned ? "Unpin" : "Pin Favorite") { model.togglePin(item) }
                            Button("Preview") { model.selectedID = item.id }
                            Button("Copy Only") { model.copy(item) }
                        }
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
                        Text(text).font(font(13, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading).padding(14)
                    }.background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ClipImage(item: item, store: model.store, thumbnail: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12).background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .modifier(ImagePreviewDrag(item: item, store: model.store, onError: { model.status = $0 }))
                    Text("Drag the preview into a document or upload target")
                        .font(font(11)).foregroundStyle(.secondary)
                }
                HStack {
                    Text(item.kind == .image ? "\(item.width) × \(item.height)" : "Plain text")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.bytes), countStyle: .file))
                }.font(font(11)).foregroundStyle(.secondary)
                Text(item.created.formatted(date: .abbreviated, time: .standard)).font(font(11)).foregroundStyle(.secondary)
            }.padding(16).id(item.id)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clipboard").font(.system(size: 38)).foregroundStyle(.tertiary)
                Text("Select a copy to preview").foregroundStyle(.secondary)
                Text("Copy it back, then paste with ⌘V.").font(font(11)).foregroundStyle(.tertiary)
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
