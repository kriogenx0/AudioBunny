import { useState, useEffect } from 'react'
import { useParams, Link } from 'react-router-dom'
import { getPreset, addPresetFavorite, removePresetFavorite, queuePresetInstall, Preset } from '../api'
import { useAuth } from '../context/AuthContext'

export default function PresetDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const [preset, setPreset] = useState<Preset | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [installQueued, setInstallQueued] = useState(false)
  const [installMsg, setInstallMsg] = useState('')

  useEffect(() => {
    if (!id) return
    setLoading(true)
    getPreset(Number(id))
      .then(setPreset)
      .catch(() => setError('Preset not found.'))
      .finally(() => setLoading(false))
  }, [id])

  const handleFavorite = async () => {
    if (!preset) return
    try {
      if (preset.favorited) {
        await removePresetFavorite(preset.id)
        setPreset({ ...preset, favorited: false })
      } else {
        await addPresetFavorite(preset.id)
        setPreset({ ...preset, favorited: true })
      }
    } catch { }
  }

  const handleInstall = async () => {
    if (!preset) return
    setInstallQueued(true)
    setInstallMsg('')
    try {
      await queuePresetInstall(preset.id)
      setInstallMsg('Install queued — your AudioBunny macOS app will install it shortly.')
      setPreset({ ...preset, installed: true })
    } catch {
      setInstallMsg('Failed to queue install.')
      setInstallQueued(false)
    }
  }

  if (loading) return <div className="spinner-wrap"><div className="spinner" /></div>
  if (error || !preset) return <div className="plugin-detail"><p className="form-error">{error || 'Not found'}</p></div>

  return (
    <div className="plugin-detail">
      <Link to="/presets" className="back-link">← Presets</Link>

      <div className="plugin-detail-header">
        <div className="plugin-icon" style={{ fontSize: 28, lineHeight: 1 }}>♪</div>
        <div>
          <h1 className="plugin-detail-name">{preset.name}</h1>
          <p className="plugin-detail-manufacturer">by {preset.author}</p>
          <div className="tag-row">
            {preset.plugin_name && <span className="tag">{preset.plugin_name}</span>}
            <span className="tag" style={{ background: 'rgba(138,43,226,0.12)', color: '#8b2de2' }}>{preset.genre}</span>
            {preset.is_community && <span className="tag" style={{ background: 'rgba(0,120,220,0.1)', color: '#0078dc' }}>Community</span>}
            {preset.tags.map(t => <span key={t} className="tag">{t}</span>)}
          </div>
        </div>

        {user && (
          <button
            className={`btn ${preset.favorited ? 'btn-primary' : 'btn-ghost'}`}
            style={{ marginLeft: 'auto' }}
            onClick={handleFavorite}
          >
            {preset.favorited ? '♥ Favorited' : '♡ Favorite'}
          </button>
        )}
      </div>

      {preset.description && (
        <section className="plugin-detail-section">
          <h2>About</h2>
          <p>{preset.description}</p>
        </section>
      )}

      <section className="plugin-detail-section">
        <h2>Details</h2>
        <table className="detail-table">
          <tbody>
            {preset.plugin_name && <tr><th>Plugin</th><td>{preset.plugin_name}</td></tr>}
            <tr><th>Author</th><td>{preset.author}</td></tr>
            <tr><th>Genre</th><td>{preset.genre}</td></tr>
            <tr><th>File type</th><td>.{preset.file_extension.toUpperCase()}</td></tr>
            {preset.file_size_bytes && <tr><th>Size</th><td>{(preset.file_size_bytes / 1024).toFixed(1)} KB</td></tr>}
            {preset.uploader_username && <tr><th>Uploaded by</th><td>{preset.uploader_username}</td></tr>}
          </tbody>
        </table>
      </section>

      <section className="plugin-detail-section">
        <h2>Install</h2>
        {!user ? (
          <p className="text-secondary">
            <Link to="/login">Sign in</Link> to install and favorite presets.
          </p>
        ) : preset.installed ? (
          <p style={{ color: 'var(--green)' }}>✓ Installed on your macOS app</p>
        ) : preset.is_downloadable ? (
          <>
            <button
              className="btn btn-primary"
              onClick={handleInstall}
              disabled={installQueued}
            >
              {installQueued ? 'Install Queued…' : 'Install on macOS App'}
            </button>
            {installMsg && <p style={{ marginTop: 8, fontSize: 13, color: 'var(--text-secondary)' }}>{installMsg}</p>}
            <p style={{ marginTop: 8, fontSize: 12, color: 'var(--text-secondary)' }}>
              This queues the install for your AudioBunny macOS app. It will download and install automatically within ~30 seconds.
            </p>
          </>
        ) : (
          <p className="text-secondary">No download available — source this preset manually.</p>
        )}
      </section>
    </div>
  )
}
