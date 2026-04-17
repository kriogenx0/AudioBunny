import SwiftUI

// MARK: - Store View

struct StoreView: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @State private var selectedPlugin: CatalogPlugin? = nil

    var body: some View {
        NavigationSplitView {
            CatalogSidebarView(selectedPlugin: $selectedPlugin)
        } detail: {
            if let plugin = selectedPlugin {
                CatalogPluginDetailView(plugin: plugin)
            } else {
                Text("Select a plugin to view details")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Catalog Sidebar

struct CatalogSidebarView: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @Binding var selectedPlugin: CatalogPlugin?

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            CatalogStatsBar()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

            Divider()

            // Filters
            CatalogFilterBar()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Plugin list
            let plugins = catalogManager.filteredPlugins(installedPlugins: manager.plugins)
            if plugins.isEmpty {
                Text("No plugins found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(plugins, selection: $selectedPlugin) { plugin in
                    CatalogPluginRowView(plugin: plugin)
                        .tag(plugin)
                }
                .listStyle(.sidebar)
            }
        }
        .searchable(text: $catalogManager.searchText, prompt: "Search catalog")
        .navigationTitle("Browse Plugins")
        .frame(minWidth: 300)
    }
}

// MARK: - Catalog Stats Bar

struct CatalogStatsBar: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager

    var body: some View {
        let installedCount = catalogManager.catalogPlugins.filter {
            catalogManager.isInstalled($0, in: manager.plugins)
        }.count
        HStack(spacing: 16) {
            statItem(catalogManager.catalogPlugins.count, label: "Available", color: .primary)
            statItem(installedCount, label: "Installed", color: .green)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func statItem(_ count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Catalog Filter Bar

struct CatalogFilterBar: View {
    @EnvironmentObject var catalogManager: CatalogManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category filter
            HStack(spacing: 6) {
                Text("Type:")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                filterChip("All", selected: catalogManager.filterCategory == nil) {
                    catalogManager.filterCategory = nil
                }
                ForEach(PluginCategory.allCases) { category in
                    filterChip(category.rawValue, selected: catalogManager.filterCategory == category) {
                        catalogManager.filterCategory = category
                    }
                }
            }

            // Format filter
            HStack(spacing: 6) {
                Text("Format:")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                filterChip("All", selected: catalogManager.filterFormat == nil) {
                    catalogManager.filterFormat = nil
                }
                ForEach(["AU", "VST2", "VST3"], id: \.self) { format in
                    filterChip(format, selected: catalogManager.filterFormat == format) {
                        catalogManager.filterFormat = format
                    }
                }
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Catalog Plugin Row

struct CatalogPluginRowView: View {
    let plugin: CatalogPlugin
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: plugin.category.icon)
                .foregroundStyle(categoryColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                    .font(.body)
                    .lineLimit(1)
                Text(plugin.developer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if catalogManager.isInstalled(plugin, in: manager.plugins) {
                Text("Installed")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 2)
    }

    private var categoryColor: Color {
        plugin.category == .instrument ? .purple : .teal
    }
}

// MARK: - Catalog Plugin Detail

struct CatalogPluginDetailView: View {
    let plugin: CatalogPlugin
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager

    private var installedPlugin: AudioPlugin? {
        catalogManager.installedPlugin(for: plugin, in: manager.plugins)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: plugin.category.icon)
                        .font(.largeTitle)
                        .foregroundStyle(categoryColor)
                        .frame(width: 50, height: 50)
                        .background(categoryColor.opacity(0.1))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(plugin.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(plugin.developer)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            // Category badge
                            Text(plugin.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(categoryColor.opacity(0.15))
                                .foregroundStyle(categoryColor)
                                .cornerRadius(6)

                            // Format chips
                            ForEach(plugin.formats, id: \.self) { format in
                                Text(format)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .foregroundStyle(.secondary)
                                    .cornerRadius(6)
                            }

                            // Price
                            Text(plugin.price)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(6)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Description
                GroupBox("About") {
                    Text(plugin.description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }

                // Details table
                GroupBox("Details") {
                    VStack(spacing: 0) {
                        infoRow("Developer", plugin.developer)
                        infoRow("Version", plugin.version)
                        infoRow("Category", plugin.category.rawValue)
                        infoRow("Formats", plugin.formats.joined(separator: ", "))
                        infoRow("Price", plugin.price)
                        if !plugin.tags.isEmpty {
                            infoRow("Tags", plugin.tags.joined(separator: ", "))
                        }
                    }
                }

                // Actions
                GroupBox("Actions") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let installed = installedPlugin {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Installed — \(installed.type.rawValue)")
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            Button(role: .destructive, action: { manager.deletePlugin(installed) }) {
                                Label("Uninstall Plugin", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)

                            Text("Permanently removes the plugin file from your system.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(action: { catalogManager.openWebsite(plugin) }) {
                                Label("Get Plugin", systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Opens the developer's website to download and install this plugin.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Button(action: { catalogManager.openWebsite(plugin) }) {
                            Label("Visit Website", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(plugin.name)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        Divider()
    }

    private var categoryColor: Color {
        plugin.category == .instrument ? .purple : .teal
    }
}
