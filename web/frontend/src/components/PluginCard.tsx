import { Plugin, addFavorite, removeFavorite } from '../api'
import { useAuth } from '../context/AuthContext'
import { useNavigate, Link } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'

interface PluginCardProps {
  plugin: Plugin
}

const TYPE_BADGE: Record<string, string> = {
  'Audio Unit': 'badge-au',
  'VST 2': 'badge-vst2',
  'VST 3': 'badge-vst3',
}

const TYPE_BG: Record<string, string> = {
  'Audio Unit': '#3b2fa0',
  'VST 2': '#7a5a0a',
  'VST 3': '#0e5c3a',
}

export default function PluginCard({ plugin }: PluginCardProps) {
  const { user } = useAuth()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [pending, setPending] = useState(false)

  const toggleFavorite = async (e: React.MouseEvent) => {
    e.preventDefault()
    if (!user) { navigate('/login'); return }
    if (pending) return
    setPending(true)
    try {
      if (plugin.favorited) {
        await removeFavorite(plugin.id)
      } else {
        await addFavorite(plugin.id)
      }
      qc.invalidateQueries({ queryKey: ['plugins'] })
      qc.invalidateQueries({ queryKey: ['favorites'] })
    } finally {
      setPending(false)
    }
  }

  return (
    <Link to={`/plugin/${plugin.id}`} className="plugin-card">
      <div className="plugin-card-body">
        <div className="plugin-card-top">
          <PluginIcon plugin={plugin} typeBg={TYPE_BG[plugin.plugin_type] ?? '#2a2a3a'} size={56} />
          <div className="plugin-card-info">
            <div className="plugin-card-name">{plugin.name}</div>
            <div className="plugin-card-mfr">{plugin.manufacturer}</div>
          </div>
          <button
            className={`btn-icon ${plugin.favorited ? 'favorited' : ''}`}
            onClick={toggleFavorite}
            aria-label={plugin.favorited ? 'Remove from favorites' : 'Add to favorites'}
            title={plugin.favorited ? 'Remove from favorites' : 'Add to favorites'}
          >
            <HeartIcon filled={plugin.favorited} />
          </button>
        </div>

        <div className="plugin-card-badges">
          <span className={`badge ${TYPE_BADGE[plugin.plugin_type] ?? ''}`}>
            {plugin.plugin_type}
          </span>
          {plugin.is_free
            ? <span className="badge badge-free">Free</span>
            : <span className="badge badge-paid">${plugin.price_usd}</span>
          }
        </div>

        {plugin.description && (
          <p className="plugin-card-desc">{plugin.description}</p>
        )}
      </div>
    </Link>
  )
}

function PluginIcon({ plugin, typeBg, size }: { plugin: Plugin; typeBg: string; size: number }) {
  const [imgError, setImgError] = useState(false)
  const radius = Math.round(size * 0.18)
  const fontSize = Math.round(size * 0.4)

  if (plugin.thumbnail_url && !imgError) {
    return (
      <img
        className="plugin-icon-img"
        src={`/api${plugin.thumbnail_url}`}
        alt={plugin.name}
        width={size}
        height={size}
        style={{ borderRadius: radius }}
        onError={() => setImgError(true)}
      />
    )
  }

  return (
    <div
      className="plugin-icon-fallback"
      style={{ width: size, height: size, borderRadius: radius, background: typeBg, fontSize }}
    >
      {plugin.name.charAt(0).toUpperCase()}
    </div>
  )
}

function HeartIcon({ filled }: { filled: boolean }) {
  return filled ? (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
    </svg>
  ) : (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
    </svg>
  )
}

export { PluginIcon }
