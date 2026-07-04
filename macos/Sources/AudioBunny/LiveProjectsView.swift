import SwiftUI
import UniformTypeIdentifiers

struct LiveProjectsView: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager
    @State private var selectedProjectID: UUID?
    @State private var showDirectoryPicker = false

    var selectedProject: LiveProject? {
        liveProjectManager.projects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarContent
        } detail: {
            detailContent
        }
        .removeSidebarToggle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Scan Folder…") { showDirectoryPicker = true }
                    .disabled(liveProjectManager.isScanning)
            }
        }
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await liveProjectManager.scanDirectory(url) }
            }
        }
    }

    @ViewBuilder
    var sidebarContent: some View {
        ZStack {
            if liveProjectManager.projects.isEmpty && !liveProjectManager.isScanning {
                LiveEmptyView(
                    icon: "folder.badge.questionmark",
                    title: "No Projects",
                    message: "Click \"Scan Folder\" to scan a directory for Ableton Live projects."
                )
            } else {
                List(liveProjectManager.projects, id: \.id, selection: $selectedProjectID) { project in
                    LiveProjectRowView(project: project, installedPlugins: pluginManager.plugins)
                        .tag(project.id)
                }
                .listStyle(.sidebar)
            }

            if liveProjectManager.isScanning {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .navigationTitle("Live Projects")
        .frame(minWidth: 220)
    }

    @ViewBuilder
    var detailContent: some View {
        if let project = selectedProject {
            LiveProjectDetailView(project: project)
        } else if liveProjectManager.projects.isEmpty {
            LiveEmptyView(
                icon: "metronome",
                title: "Scan a Folder",
                message: "Scan a folder to see which plugins your Ableton Live projects use."
            )
        } else {
            Text("Select a project")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Project Row

struct LiveProjectRowView: View {
    let project: LiveProject
    let installedPlugins: [AudioPlugin]

    var missingCount: Int {
        project.plugins.filter { !$0.isInstalled(in: installedPlugins) }.count
    }

    var body: some View {
        HStack {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                Text(project.plugins.isEmpty ? "No plugins" : "\(project.plugins.count) plugin\(project.plugins.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if missingCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(missingCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Project Detail

struct LiveProjectDetailView: View {
    @EnvironmentObject var pluginManager: PluginManager
    let project: LiveProject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(project.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                if project.plugins.isEmpty {
                    LiveEmptyView(
                        icon: "puzzlepiece",
                        title: "No Plugins Found",
                        message: "This project uses no plugins, or the file could not be parsed."
                    )
                } else {
                    let missing = project.plugins.filter { !$0.isInstalled(in: pluginManager.plugins) }
                    let installed = project.plugins.filter { $0.isInstalled(in: pluginManager.plugins) }

                    if !missing.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(missing) { plugin in
                                    PluginUsageRow(plugin: plugin, isInstalled: false)
                                    if plugin.id != missing.last?.id { Divider() }
                                }
                            }
                        } label: {
                            Label("Missing Plugins (\(missing.count))", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    if !installed.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(installed) { plugin in
                                    PluginUsageRow(plugin: plugin, isInstalled: true)
                                    if plugin.id != installed.last?.id { Divider() }
                                }
                            }
                        } label: {
                            Label("Installed Plugins (\(installed.count))", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(project.name)
    }
}

// MARK: - Plugin Usage Row

struct PluginUsageRow: View {
    let plugin: LiveProjectPlugin
    let isInstalled: Bool

    var body: some View {
        HStack {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isInstalled ? .green : .red)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                if let mfr = plugin.manufacturer {
                    Text(mfr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let type = plugin.type {
                Text(type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State Helper

struct LiveEmptyView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
