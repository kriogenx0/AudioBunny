import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { getPlugins, addFavorite, removeFavorite, Plugin } from '../api'
import { useAuth } from '../context/AuthContext'
import { useQueryClient } from '@tanstack/react-query'

interface Props { search: string }

type CategoryFilter = 'instrument' | 'effect' | null
type FormatFilter = 'AU' | 'VST2' | 'VST3' | null

export default function CatalogPage({ search }: Props) {
  const [category, setCategory] = useState<CategoryFilter>(null)
  const [format, setFormat] = useState<FormatFilter>(null)
  const [freeOnly, setFreeOnly] = useState(false)

  const { data: plugins = [], isLoading } = useQuery({
    queryKey: ['plugins', search],
    queryFn: () => getPlugins({ q: search || undefined, limit: 200 }),
  })

  // Client-side filter for category, format, free (API doesn't have these filters yet)
  const filtered = plugins.filter(p => {
    if (category === 'instrument' && p.category !== 'instrument') return false
    if (category === 'effect'     && p.category !== 'effect')     return false
    if (format && !p.formats?.includes(format))                   return false
    if (freeOnly && !p.is_free)                                   return false
    return true
  })

  const toggle = (val: any, cur: any, set: (v: any) => void) =>
    set(cur === val ? null : val)

  return (
    <main className="page">
      {/* Filter bar */}
      <div className="filters" style={{ marginBottom: 24 }}>
        <div className="filter-chips">
          <button className={`chip ${!category ? 'active' : ''}`} onClick={() => setCategory(null)}>All</button>
          <button className={`chip ${category === 'instrument' ? 'active' : ''}`} onClick={() => toggle('instrument', category, setCategory)}>Instruments</button>
          <button className={`chip ${category === 'effect' ? 'active' : ''}`} onClick={() => toggle('effect', category, setCategory)}>Effects</button>
        </div>
        <div className="filter-chips" style={{ marginLeft: 8 }}>
          {(['AU', 'VST2', 'VST3'] as const).map(f => (
            <button key={f} className={`chip ${format === f ? 'active' : ''}`} onClick={() => toggle(f, format, setFormat)}>{f}</button>
          ))}
        </div>
        <button className={`chip ${freeOnly ? 'active' : ''}`} style={{ marginLeft: 8 }} onClick={() => setFreeOnly(v => !v)}>Free</button>
        <div className="filters-right">
          <span className="results-count">{filtered.length} plugin{filtered.length !== 1 ? 's' : ''}</span>
        </div>
      </div>

      {isLoading ? (
        <div className="spinner-wrap"><div className="spinner" /></div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">🔍</span>
          <p className="empty-title">No plugins found</p>
          <p className="empty-desc">Try a different search or filter.</p>
        </div>
      ) : (
        <div className="plugin-grid">
          {filtered.map(p => <DiscoverCard key={p.id} plugin={p} />)}
        </div>
      )}
    </main>
  )
}

function DiscoverCard({ plugin }: { plugin: Plugin }) {
  const { user } = useAuth()
  const qc = useQueryClient()
  const [pending, setPending] = useState(false)

  const toggleFav = async (e: React.MouseEvent) => {
    e.preventDefault()
    if (!user || pending) return
    setPending(true)
    try {
      plugin.favorited ? await removeFavorite(plugin.id) : await addFavorite(plugin.id)
      qc.invalidateQueries({ queryKey: ['plugins'] })
      qc.invalidateQueries({ queryKey: ['favorites'] })
    } finally { setPending(false) }
  }

  const price = plugin.is_free ? 'Free' : (plugin.price_usd ? `$${plugin.price_usd}` : null)
  const catIcon = plugin.category === 'instrument' ? '♬' : plugin.category === 'effect' ? '〜' : null
  const catLabel = plugin.category === 'instrument' ? 'Instrument' : plugin.category === 'effect' ? 'Effect' : null
  const catColor = plugin.category === 'instrument' ? 'rgba(138,43,226,.15)' : 'rgba(0,128,128,.12)'
  const catText  = plugin.category === 'instrument' ? '#b06ef5' : '#2ab5b5'

  return (
    <Link to={`/plugin/${plugin.id}`} className="plugin-card">
      {/* Art */}
      <div className="plugin-card-art">
        {plugin.thumbnail_url
          ? <img src={`/api/v1${plugin.thumbnail_url}`} alt={plugin.name} className="plugin-card-art-img" />
          : <div className="plugin-card-art-placeholder" style={{ background: placeholderGradient(plugin.name) }}>
              {catIcon && <span style={{ fontSize: 28, opacity: 0.7 }}>{catIcon}</span>}
              <span className="plugin-card-art-initial">{plugin.name.charAt(0).toUpperCase()}</span>
            </div>
        }
      </div>

      {/* Info */}
      <div className="plugin-card-body">
        <div className="plugin-card-top">
          <div className="plugin-card-info">
            <div className="plugin-card-name">{plugin.name}</div>
            <div className="plugin-card-mfr">{plugin.manufacturer}</div>
          </div>
          {user && (
            <button className={`btn-icon ${plugin.favorited ? 'favorited' : ''}`} onClick={toggleFav} title="Favorite">
              {plugin.favorited ? '♥' : '♡'}
            </button>
          )}
        </div>

        <div className="plugin-card-badges">
          {catLabel && (
            <span className="badge" style={{ background: catColor, color: catText }} title={catLabel}>
              {catIcon}
            </span>
          )}
          {(plugin.formats ?? []).map(f => (
            <span key={f} className="badge" style={{ background: 'rgba(255,255,255,.06)', color: 'var(--text-muted)' }}>{f}</span>
          ))}
          {price && (
            <span className="badge" style={{
              background: plugin.is_free ? 'rgba(52,211,153,.15)' : 'rgba(255,255,255,.06)',
              color: plugin.is_free ? 'var(--green)' : 'var(--text-muted)',
              marginLeft: 'auto',
            }}>{price}</span>
          )}
        </div>
      </div>
    </Link>
  )
}

const GRADIENTS = [
  'linear-gradient(135deg,#5b21b6,#7c3aed)',
  'linear-gradient(135deg,#0f766e,#0d9488)',
  'linear-gradient(135deg,#1d4ed8,#3b82f6)',
  'linear-gradient(135deg,#9333ea,#c026d3)',
  'linear-gradient(135deg,#be185d,#ec4899)',
  'linear-gradient(135deg,#c2410c,#f97316)',
  'linear-gradient(135deg,#047857,#10b981)',
]

function placeholderGradient(name: string) {
  let h = 0
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0
  return GRADIENTS[h % GRADIENTS.length]
}
