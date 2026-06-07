import { useState, useEffect, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { getPresets, addPresetFavorite, removePresetFavorite, queuePresetInstall, Preset } from '../api'
import { useAuth } from '../context/AuthContext'

export default function PresetsPage() {
  const { user } = useAuth()
  const [presets, setPresets] = useState<Preset[]>([])
  const [selectedPluginId, setSelectedPluginId] = useState<number | null>(null)
  const [selectedGenre, setSelectedGenre] = useState('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await getPresets({
        plugin_id: selectedPluginId ?? undefined,
        genre: selectedGenre || undefined,
        q: search || undefined,
      })
      setPresets(data)
    } catch {
      setError('Failed to load presets.')
    } finally {
      setLoading(false)
    }
  }, [selectedPluginId, selectedGenre, search])

  useEffect(() => { load() }, [load])

  // Derive plugin groups from loaded presets
  const allPresets = useCallback(() => {
    const map = new Map<number, string>()
    presets.forEach(p => { if (!map.has(p.plugin_id)) map.set(p.plugin_id, p.plugin_name ?? 'Unknown') })
    return Array.from(map.entries()).sort((a, b) => a[1].localeCompare(b[1]))
  }, [presets])

  const genres = Array.from(new Set(
    (selectedPluginId ? presets.filter(p => p.plugin_id === selectedPluginId) : presets)
      .map(p => p.genre)
  )).sort()

  const handlePluginSelect = (id: number | null) => {
    setSelectedPluginId(id)
    setSelectedGenre('')
  }

  return (
    <div className="presets-layout">
      {/* Sidebar */}
      <aside className="presets-sidebar">
        <div className="sidebar-section">
          <div className="sidebar-section-label">Plugin</div>
          <button
            className={`sidebar-nav-item ${selectedPluginId === null ? 'active' : ''}`}
            onClick={() => handlePluginSelect(null)}
          >
            <span>All Presets</span>
            <span className="sidebar-count">{presets.length}</span>
          </button>
          {allPresets().map(([id, name]) => (
            <button
              key={id}
              className={`sidebar-nav-item ${selectedPluginId === id ? 'active' : ''}`}
              onClick={() => handlePluginSelect(id)}
            >
              <span>{name}</span>
              <span className="sidebar-count">{presets.filter(p => p.plugin_id === id).length}</span>
            </button>
          ))}
        </div>

        {genres.length > 0 && (
          <div className="sidebar-section">
            <div className="sidebar-section-label">Genre</div>
            <div className="filter-chips" style={{ paddingLeft: 4 }}>
              <button
                className={`chip ${!selectedGenre ? 'active' : ''}`}
                onClick={() => setSelectedGenre('')}
              >All</button>
              {genres.map(g => (
                <button
                  key={g}
                  className={`chip ${selectedGenre === g ? 'active' : ''}`}
                  onClick={() => setSelectedGenre(g)}
                >{g}</button>
              ))}
            </div>
          </div>
        )}
      </aside>

      {/* Main */}
      <div className="presets-main">
        <div className="presets-toolbar">
          <input
            className="form-input"
            style={{ maxWidth: 300 }}
            placeholder="Search presets, artists, genres…"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          <span className="presets-count">{presets.length} preset{presets.length !== 1 ? 's' : ''}</span>
        </div>

        {loading ? (
          <div className="spinner-wrap"><div className="spinner" /></div>
        ) : error ? (
          <p className="form-error">{error}</p>
        ) : presets.length === 0 ? (
          <div className="empty-state">
            <span className="empty-icon">♪</span>
            <p className="empty-title">No presets found</p>
            <p className="empty-desc">Try adjusting your search or filters.</p>
          </div>
        ) : (
          <div className="preset-grid">
            {presets.map(preset => (
              <PresetCard
                key={preset.id}
                preset={preset}
                canInstall={!!user}
                onToggleFav={async () => {
                  try {
                    if (preset.favorited) await removePresetFavorite(preset.id)
                    else await addPresetFavorite(preset.id)
                    load()
                  } catch { }
                }}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Preset Card ──────────────────────────────────────────────────────────────

function PresetCard({
  preset,
  canInstall,
  onToggleFav,
}: {
  preset: Preset
  canInstall: boolean
  onToggleFav: () => void
}) {
  const [queued, setQueued] = useState(preset.installed)

  const handleInstall = async (e: React.MouseEvent) => {
    e.preventDefault()
    setQueued(true)
    try { await queuePresetInstall(preset.id) } catch { setQueued(false) }
  }

  return (
    <Link to={`/presets/${preset.id}`} className="preset-card">
      <div className="preset-card-top">
        <div className="preset-card-icon">♪</div>
        <div style={{ minWidth: 0 }}>
          <div className="preset-card-name">{preset.name}</div>
          <div className="preset-card-author">{preset.author}</div>
        </div>
        {canInstall && (
          <button
            className={`btn-icon ${preset.favorited ? 'favorited' : ''}`}
            onClick={e => { e.preventDefault(); onToggleFav() }}
            title={preset.favorited ? 'Remove from favorites' : 'Add to favorites'}
            style={{ marginLeft: 'auto', flexShrink: 0 }}
          >
            {preset.favorited ? '♥' : '♡'}
          </button>
        )}
      </div>

      <div className="preset-card-footer">
        <span className="preset-genre-tag">{preset.genre}</span>
        {preset.is_community && <span className="preset-community-tag">Community</span>}
        <span style={{ flex: 1 }} />
        {queued && <span className="installed-badge">Installed</span>}
        {canInstall && !queued && preset.is_downloadable && (
          <button
            className="btn btn-primary btn-sm"
            onClick={handleInstall}
            title="Queue install to macOS app"
          >
            Install
          </button>
        )}
      </div>
    </Link>
  )
}
