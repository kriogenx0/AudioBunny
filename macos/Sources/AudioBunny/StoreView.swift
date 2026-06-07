import SwiftUI

// MARK: - Discover (Store) View

struct StoreView: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var selectedPlugin: CatalogPlugin? = nil

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
            .sheet(item: $selectedPlugin) { plugin in
                CatalogPluginSheet(plugin: plugin)
                    .environmentObject(manager)
                    .environmentObject(catalogManager)
                    .environmentObject(downloadManager)
            }
        }
    }

    // MARK: Filter bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", icon: "square.grid.2x2", selected: catalogManager.filterCategory == nil) {
                        catalogManager.filterCategory = nil
                    }
                    filterChip("Instruments", icon: PluginCategory.instrument.icon,
                               selected: catalogManager.filterCategory == .instrument) {
                        catalogManager.filterCategory = .instrument
                    }
                    filterChip("Effects", icon: PluginCategory.effect.icon,
                               selected: catalogManager.filterCategory == .effect) {
                        catalogManager.filterCategory = .effect
                    }

                    Divider().frame(height: 20)

                    filterChip("AU",   icon: formatIcon("AU").icon,   color: formatIcon("AU").color,
                               selected: catalogManager.filterFormat == "AU")   { catalogManager.filterFormat = catalogManager.filterFormat == "AU"   ? nil : "AU" }
                    filterChip("VST2", icon: formatIcon("VST2").icon, color: formatIcon("VST2").color,
                               selected: catalogManager.filterFormat == "VST2") { catalogManager.filterFormat = catalogManager.filterFormat == "VST2" ? nil : "VST2" }
                    filterChip("VST3", icon: formatIcon("VST3").icon, color: formatIcon("VST3").color,
                               selected: catalogManager.filterFormat == "VST3") { catalogManager.filterFormat = catalogManager.filterFormat == "VST3" ? nil : "VST3" }
                }
                .padding(.horizontal, 2)
            }
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
                        PluginDiscoverCard(plugin: plugin)
                            .onTapGesture { selectedPlugin = plugin }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func filterChip(_ label: String, icon: String, color: Color = .primary,
                             selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundStyle(selected ? Color.accentColor : color == .primary ? Color.primary : color)
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
            // Art / icon area
            pluginArt
                .frame(height: 110)
                .clipped()

            // Info area
            VStack(alignment: .leading, spacing: 6) {
                Text(plugin.name)
                    .font(.headline).lineLimit(1)
                Text(plugin.developer)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)

                HStack(spacing: 5) {
                    categoryBadge
                    ForEach(plugin.formats, id: \.self) { format in
                        formatBadge(format)
                    }
                    Spacer()
                    priceBadge
                }
            }
            .padding(12)
        }
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
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [placeholderColor.opacity(0.7), placeholderColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: plugin.category.icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                Text(plugin.name.prefix(1))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: Badges

    private var categoryBadge: some View {
        Label(plugin.category.label, systemImage: plugin.category.icon)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(categoryColor.opacity(0.15))
            .foregroundStyle(categoryColor)
            .cornerRadius(4)
    }

    @ViewBuilder
    private func formatBadge(_ format: String) -> some View {
        let f = formatIcon(format)
        Label(format, systemImage: f.icon)
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(f.color.opacity(0.12))
            .foregroundStyle(f.color)
            .cornerRadius(4)
    }

    private var priceBadge: some View {
        Text(plugin.price)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(plugin.price.lowercased() == "free" ? Color.green : Color.secondary)
    }

    // MARK: Derived colors

    private var categoryColor: Color {
        plugin.category == .instrument ? .purple : .teal
    }

    private var placeholderColor: Color {
        // Deterministic color from plugin name hash
        let colors: [Color] = [.purple, .teal, .blue, .indigo, .pink, .orange, .mint]
        let idx = abs(plugin.name.hashValue) % colors.count
        return colors[idx]
    }
}

// MARK: - Plugin Sheet (detail)

struct CatalogPluginSheet: View {
    let plugin: CatalogPlugin
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    private var installedPlugin: AudioPlugin? {
        catalogManager.installedPlugin(for: plugin, in: manager.plugins)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header art
            ZStack(alignment: .bottomLeading) {
                PluginDiscoverCard(plugin: plugin)
                    .frame(height: 140)
                    .clipped()
                    .allowsHitTesting(false)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plugin.name)
                            .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                        Text(plugin.developer)
                            .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 140)
            .cornerRadius(0)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Badges row
                    HStack(spacing: 6) {
                        Label(plugin.category.label, systemImage: plugin.category.icon)
                            .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                            .background((plugin.category == .instrument ? Color.purple : Color.teal).opacity(0.15))
                            .foregroundStyle(plugin.category == .instrument ? .purple : .teal)
                            .cornerRadius(6)
                        ForEach(plugin.formats, id: \.self) { format in
                            let f = formatIcon(format)
                            Label(format, systemImage: f.icon)
                                .font(.caption).padding(.horizontal, 6).padding(.vertical, 3)
                                .background(f.color.opacity(0.12)).foregroundStyle(f.color)
                                .cornerRadius(6)
                        }
                        Text(plugin.price)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(plugin.price.lowercased() == "free" ? Color.green : .secondary)
                        Spacer()
                    }

                    // Description
                    GroupBox("About") {
                        Text(plugin.description)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    }

                    // Details
                    GroupBox("Details") {
                        VStack(spacing: 0) {
                            infoRow("Developer", plugin.developer)
                            infoRow("Version",   plugin.version)
                            infoRow("Formats",   plugin.formats.joined(separator: ", "))
                            if !plugin.tags.isEmpty {
                                infoRow("Tags", plugin.tags.joined(separator: ", "))
                            }
                        }
                    }

                    // Actions
                    GroupBox("Actions") {
                        VStack(alignment: .leading, spacing: 12) {
                            actionsContent
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 580)
    }

    // MARK: Actions

    @ViewBuilder
    private var actionsContent: some View {
        if let state = downloadManager.states[plugin.id] {
            installProgressPanel(state)
        } else if let installed = installedPlugin {
            installedPanel(installed)
        } else if plugin.isDownloadable {
            downloadablePanel
        } else {
            websiteOnlyPanel
        }
        Divider()
        Button { catalogManager.openWebsite(plugin) } label: {
            Label("Visit Website", systemImage: "safari")
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func installProgressPanel(_ state: InstallState) -> some View {
        if state.isFailed {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(state.label).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Retry")   { downloadManager.dismissError(for: plugin.id); downloadManager.install(plugin) }.buttonStyle(.borderedProminent)
                Button("Dismiss") { downloadManager.dismissError(for: plugin.id) }.buttonStyle(.bordered)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: state.progressFraction) {
                    Text(state.label).font(.caption).foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                Button("Cancel") { downloadManager.cancel(plugin.id) }.buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private func installedPanel(_ installed: AudioPlugin) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Installed — \(installed.type.rawValue)").foregroundStyle(.secondary)
        }
        Divider()
        Button(role: .destructive) { manager.deletePlugin(installed) } label: {
            Label("Uninstall Plugin", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        Text("Permanently removes the plugin file from your system.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var downloadablePanel: some View {
        Button { downloadManager.install(plugin) } label: {
            Label("Install", systemImage: "arrow.down.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        Text(plugin.githubRepo != nil
             ? "Fetches the latest release from GitHub and installs automatically."
             : "Downloads and installs the plugin automatically.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var websiteOnlyPanel: some View {
        Button { catalogManager.openWebsite(plugin) } label: {
            Label("Get Plugin", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.borderedProminent)
        Text("Opens the developer's website to download and install manually.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        Divider()
    }
}

// MARK: - Shared format icon helper

func formatIcon(_ format: String) -> (icon: String, color: Color) {
    switch format {
    case "AU":   return ("waveform",         .blue)
    case "VST2": return ("puzzlepiece",      .purple)
    case "VST3": return ("puzzlepiece.fill", .indigo)
    default:     return ("music.note",       .secondary)
    }
}
