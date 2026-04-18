import { useParams, Link, useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { getPlugin, addFavorite, removeFavorite } from '../api'
import { useAuth } from '../context/AuthContext'
import { useState } from 'react'

const TYPE_EMOJI: Record<string, string> = {
  'Audio Unit': '🎛️',
  'VST 2': '🔌',
  'VST 3': '🎚️',
}

const TYPE_BADGE: Record<string, string> = {
  'Audio Unit': 'badge-au',
  'VST 2': 'badge-vst2',
  'VST 3': 'badge-vst3',
}

export default function PluginDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { user } = useAuth()
  const qc = useQueryClient()
  const [pending, setPending] = useState(false)

  const { data: plugin, isLoading, isError } = useQuery({
    queryKey: ['plugin', id],
    queryFn: () => getPlugin(id!),
    enabled: !!id,
  })

  const toggleFavorite = async () => {
    if (!user) { navigate('/login'); return }
    if (!plugin || pending) return
    setPending(true)
    try {
      if (plugin.favorited) {
        await removeFavorite(plugin.id)
      } else {
        await addFavorite(plugin.id)
      }
      qc.invalidateQueries({ queryKey: ['plugin', id] })
      qc.invalidateQueries({ queryKey: ['plugins'] })
      qc.invalidateQueries({ queryKey: ['favorites'] })
    } finally {
      setPending(false)
    }
  }

  if (isLoading) return (
    <main className="page">
      <div className="spinner-wrap"><div className="spinner" /></div>
    </main>
  )

  if (isError || !plugin) return (
    <main className="page">
      <div className="empty-state">
        <span className="empty-icon">⚠️</span>
        <p className="empty-title">Plugin not found</p>
        <Link to="/" className="btn btn-primary">Back to catalog</Link>
      </div>
    </main>
  )

  const tags = plugin.tags ? plugin.tags.split(',').map((t) => t.trim()) : []

  return (
    <main className="page">
      <Link to="/" className="detail-back">
        ← Back to catalog
      </Link>

      <div className="detail-layout">
        <div>
          <div className="detail-thumb">
            {TYPE_EMOJI[plugin.plugin_type] ?? '🎵'}
          </div>

          <div className="detail-title">{plugin.name}</div>
          <div className="detail-mfr">{plugin.manufacturer}</div>

          <div className="detail-badges">
            <span className={`badge ${TYPE_BADGE[plugin.plugin_type] ?? ''}`}>
              {plugin.plugin_type}
            </span>
            {plugin.is_free
              ? <span className="badge badge-free">Free</span>
              : <span className="badge badge-paid">${plugin.price_usd}</span>
            }
          </div>

          {plugin.description && (
            <p className="detail-desc">{plugin.description}</p>
          )}

          {tags.length > 0 && (
            <div className="detail-tags">
              {tags.map((t) => <span key={t} className="detail-tag">#{t}</span>)}
            </div>
          )}
        </div>

        <aside className="detail-sidebar">
          <div className={`detail-price ${plugin.is_free ? 'free' : ''}`}>
            {plugin.is_free ? 'Free' : `$${plugin.price_usd}`}
          </div>

          <button
            className={`btn ${plugin.favorited ? 'btn-secondary' : 'btn-primary'}`}
            onClick={toggleFavorite}
            disabled={pending}
          >
            {plugin.favorited ? '♥ Remove from favorites' : '♡ Add to favorites'}
          </button>

          {plugin.download_url && (
            <a
              href={`/api${plugin.download_url}`}
              className="btn btn-ghost"
              download
            >
              ↓ Download
            </a>
          )}

          <div className="detail-meta">
            {plugin.version && (
              <div className="detail-meta-row">
                <span>Version</span><span>{plugin.version}</span>
              </div>
            )}
            <div className="detail-meta-row">
              <span>Format</span><span>{plugin.plugin_type}</span>
            </div>
            {plugin.file_size_bytes && (
              <div className="detail-meta-row">
                <span>Size</span>
                <span>{(plugin.file_size_bytes / 1_000_000).toFixed(1)} MB</span>
              </div>
            )}
          </div>

          {!user && (
            <p style={{ fontSize: 12, color: 'var(--text-muted)', textAlign: 'center' }}>
              <Link to="/register" style={{ color: 'var(--accent)' }}>Create an account</Link> to
              save favorites and sync to macOS
            </p>
          )}
        </aside>
      </div>
    </main>
  )
}
