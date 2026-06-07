import SwiftUI

// MARK: - Discover (Store) View

struct StoreView: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @EnvironmentObject var downloadManager: DownloadManager

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filterBar
                    pluginGrid
                }
                .padding(20)
            }
            .navigationTitle("Discover")
            .searchable(text: $catalogManager.searchText, placement: .toolbar, prompt: "Search plugins")
        }
    }

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Category
                filterChip("All",         icon: "square.grid.2x2",             selected: catalogManager.filterCategory == nil) {
                    catalogManager.filterCategory = nil
                }
                filterChip("Instruments", icon: PluginCategory.instrument.icon, selected: catalogManager.filterCategory == .instrument) {
                    catalogManager.filterCategory = catalogManager.filterCategory == .instrument ? nil : .instrument
                }
                filterChip("Effects",     icon: PluginCategory.effect.icon,     selected: catalogManager.filterCategory == .effect) {
                    catalogManager.filterCategory = catalogManager.filterCategory == .effect ? nil : .effect
                }

                Divider().frame(height: 20)

                // Format (text-only chips, matching card badges)
                textChip("AU",   selected: catalogManager.filterFormat == "AU")   { catalogManager.filterFormat = catalogManager.filterFormat == "AU"   ? nil : "AU" }
                textChip("VST2", selected: catalogManager.filterFormat == "VST2") { catalogManager.filterFormat = catalogManager.filterFormat == "VST2" ? nil : "VST2" }
                textChip("VST3", selected: catalogManager.filterFormat == "VST3") { catalogManager.filterFormat = catalogManager.filterFormat == "VST3" ? nil : "VST3" }

                Divider().frame(height: 20)

                // Free toggle
                filterChip("Free", icon: "gift", selected: catalogManager.filterFree) {
                    catalogManager.filterFree.toggle()
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: Grid

    private var pluginGrid: some View {
        let plugins = catalogManager.filteredPlugins(installedPlugins: manager.plugins)
        return Group {
            if plugins.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle).foregroundStyle(.secondary)
                    Text("No plugins found")
                        .foregroundStyle(.secondary)
                    Text("Try a different search or filter.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(plugins) { plugin in
                        NavigationLink {
                            CatalogPluginDetailPage(plugin: plugin)
                                .environmentObject(manager)
                                .environmentObject(catalogManager)
                                .environmentObject(downloadManager)
                        } label: {
                            PluginDiscoverCard(plugin: plugin)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Chip helpers

    @ViewBuilder
    private func filterChip(_ label: String, icon: String, selected: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func textChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plugin Discover Card

struct PluginDiscoverCard: View {
    let plugin: CatalogPlugin
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pluginArt.frame(height: 110).clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(plugin.name)
                    .font(.headline).lineLimit(1).foregroundStyle(.primary)
                Text(plugin.developer)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)

                HStack(spacing: 5) {
                    categoryBadge
                    ForEach(plugin.formats, id: \.self) { formatBadge($0) }
                    Spacer()
                    priceBadge
                }
            }
            .padding(12)
            .frame(height: 72, alignment: .top)  // fixed info area height
        }
        .frame(height: 182)  // 110 art + 72 info = fixed total
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .contentShape(Rectangle())
    }

    // MARK: Art

    @ViewBuilder
    private var pluginArt: some View {
        if let urlString = plugin.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase { img.resizable().scaledToFill() }
                else { artPlaceholder }
            }
        } else {
            artPlaceholder
        }
    }

    private var artPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [placeholderColor.opacity(0.7), placeholderColor],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                Image(systemName: plugin.category.icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                Text(plugin.name.prefix(1))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: Badges

    // Icon only + tooltip — no text
    private var categoryBadge: some View {
        Image(systemName: plugin.category.icon)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(categoryColor.opacity(0.15))
            .foregroundStyle(categoryColor)
            .cornerRadius(4)
            .help(plugin.category.label)
    }

    // Text only — no icon
    @ViewBuilder
    private func formatBadge(_ format: String) -> some View {
        Text(format)
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .foregroundStyle(.secondary)
            .cornerRadius(4)
    }

    private var priceBadge: some View {
        Text(plugin.price)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(plugin.isFree ? Color.green : Color.secondary)
    }

    private var categoryColor: Color { plugin.category == .instrument ? .purple : .teal }

    private var placeholderColor: Color {
        let colors: [Color] = [.purple, .teal, .blue, .indigo, .pink, .orange, .mint]
        return colors[abs(plugin.name.hashValue) % colors.count]
    }
}

// MARK: - Full-window Plugin Detail

struct CatalogPluginDetailPage: View {
    let plugin: CatalogPlugin
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @EnvironmentObject var downloadManager: DownloadManager

    private var installedPlugin: AudioPlugin? {
        catalogManager.installedPlugin(for: plugin, in: manager.plugins)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero art
                heroArt
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()

                VStack(alignment: .leading, spacing: 24) {
                    // Header row
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(plugin.name)
                                .font(.largeTitle).fontWeight(.bold)
                            Text(plugin.developer)
                                .font(.title3).foregroundStyle(.secondary)
                            badgeRow
                        }
                        Spacer()
                        installButton
                    }

                    Divider()

                    // About
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About").font(.headline)
                        Text(plugin.description)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Details grid
                    detailsSection

                    // Tags
                    if !plugin.tags.isEmpty {
                        tagsSection
                    }
                }
                .padding(28)
            }
        }
        .navigationTitle(plugin.name)
        .navigationBarBackButtonHidden(false)
    }

    // MARK: Hero

    @ViewBuilder
    private var heroArt: some View {
        if let urlString = plugin.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase { img.resizable().scaledToFill() }
                else { heroPlaceholder }
            }
        } else {
            heroPlaceholder
        }
    }

    private var heroPlaceholder: some View {
        let color: Color = {
            let colors: [Color] = [.purple, .teal, .blue, .indigo, .pink, .orange, .mint]
            return colors[abs(plugin.name.hashValue) % colors.count]
        }()
        return ZStack {
            LinearGradient(colors: [color.opacity(0.5), color],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: plugin.category.icon)
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: Badges row

    private var badgeRow: some View {
        HStack(spacing: 6) {
            Label(plugin.category.label, systemImage: plugin.category.icon)
                .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                .background((plugin.category == .instrument ? Color.purple : Color.teal).opacity(0.15))
                .foregroundStyle(plugin.category == .instrument ? .purple : .teal)
                .cornerRadius(6)
            ForEach(plugin.formats, id: \.self) { format in
                Text(format)
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundStyle(.secondary)
                    .cornerRadius(6)
            }
            Text(plugin.price)
                .font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(plugin.isFree ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
                .foregroundStyle(plugin.isFree ? Color.green : Color.secondary)
                .cornerRadius(6)
        }
    }

    // MARK: Install button

    @ViewBuilder
    private var installButton: some View {
        if let state = downloadManager.states[plugin.id] {
            if state.isFailed {
                Button("Retry") {
                    downloadManager.dismissError(for: plugin.id)
                    downloadManager.install(plugin)
                }
                .buttonStyle(.borderedProminent).tint(.red)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: state.progressFraction)
                        .frame(width: 140)
                    Text(state.label).font(.caption).foregroundStyle(.secondary)
                    Button("Cancel") { downloadManager.cancel(plugin.id) }
                        .buttonStyle(.bordered).tint(.orange).font(.caption)
                }
            }
        } else if installedPlugin != nil {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.callout).foregroundStyle(.green)
        } else if plugin.isDownloadable {
            Button {
                downloadManager.install(plugin)
            } label: {
                Label("Install", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button {
                catalogManager.openWebsite(plugin)
            } label: {
                Label("Get Plugin", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: Details grid

    private var detailsSection: some View {
        GroupBox("Details") {
            VStack(spacing: 0) {
                detailRow("Developer", plugin.developer)
                detailRow("Version",   plugin.version)
                detailRow("Category",  plugin.category.label)
                detailRow("Formats",   plugin.formats.joined(separator: ", "))
                detailRow("Price",     plugin.price)
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7).padding(.horizontal, 8)
        Divider()
    }

    // MARK: Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.headline)
            FlowLayout(spacing: 6) {
                ForEach(plugin.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundStyle(.secondary)
                        .cornerRadius(5)
                }
            }
        }
    }
}

// MARK: - Simple flow layout for tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
                         .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let w = subview.sizeThatFits(.unspecified).width
            if x + w > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(subview)
            x += w + spacing
        }
        return rows
    }
}

// MARK: - Format icon helper (kept for any other usage)

func formatIcon(_ format: String) -> (icon: String, color: Color) {
    switch format {
    case "AU":   return ("waveform",         .blue)
    case "VST2": return ("puzzlepiece",      .purple)
    case "VST3": return ("puzzlepiece.fill", .indigo)
    default:     return ("music.note",       .secondary)
    }
}
