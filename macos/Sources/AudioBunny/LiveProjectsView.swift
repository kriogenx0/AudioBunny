import SwiftUI
import UniformTypeIdentifiers

struct LiveProjectsView: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager
    @State private var showDirectoryPicker = false

    var allPlugins: [LiveProjectPlugin] { liveProjectManager.allUniquePlugins }
    var missingPlugins: [LiveProjectPlugin] { allPlugins.filter { !$0.isInstalled(in: pluginManager.plugins) } }
    var installedPlugins: [LiveProjectPlugin] { allPlugins.filter { $0.isInstalled(in: pluginManager.plugins) } }

    var body: some View {
        List {
            if !liveProjectManager.projects.isEmpty {
                Section("Projects") {
                    ForEach(liveProjectManager.projects) { project in
                        ProjectRow(project: project)
                    }
                }

                if !missingPlugins.isEmpty {
                    Section("Missing Plugins (\(missingPlugins.count))") {
                        ForEach(missingPlugins) { plugin in
                            PluginUsageRow(
                                plugin: plugin,
                                isInstalled: false,
                                projectCount: liveProjectManager.projectCount(for: plugin)
                            )
                        }
                    }
                }

                if !installedPlugins.isEmpty {
                    Section("Installed Plugins (\(installedPlugins.count))") {
                        ForEach(installedPlugins) { plugin in
                            PluginUsageRow(
                                plugin: plugin,
                                isInstalled: true,
                                projectCount: liveProjectManager.projectCount(for: plugin)
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if liveProjectManager.projects.isEmpty && !liveProjectManager.isScanning {
                LiveEmptyView(
                    icon: "folder.badge.questionmark",
                    title: "No Projects",
                    message: "Click \"Scan Folder\" to scan a directory for Ableton Live projects."
                )
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
}

// MARK: - Project Row

struct ProjectRow: View {
    @EnvironmentObject var pluginManager: PluginManager
    let project: LiveProject

    var missingCount: Int {
        project.plugins.filter { !$0.isInstalled(in: pluginManager.plugins) }.count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                Text(project.plugins.isEmpty
                     ? "No plugins"
                     : "\(project.plugins.count) plugin\(project.plugins.count == 1 ? "" : "s")")
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

// MARK: - Plugin Usage Row

struct PluginUsageRow: View {
    let plugin: LiveProjectPlugin
    let isInstalled: Bool
    var projectCount: Int? = nil

    var body: some View {
        HStack {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isInstalled ? .green : .red)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                HStack(spacing: 8) {
                    if let mfr = plugin.manufacturer {
                        Text(mfr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let count = projectCount {
                        Text("\(count) project\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
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
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

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
