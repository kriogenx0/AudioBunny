import { Plugin, addFavorite, removeFavorite } from '../api'
import { useAuth } from '../context/AuthContext'
import { useNavigate, Link } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'

interface PluginCardProps {
  plugin: Plugin
}

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
      <div className="plugin-card-thumb">
        {TYPE_EMOJI[plugin.plugin_type] ?? '🎵'}
      </div>

      <div className="plugin-card-body">
        <div className="plugin-card-header">
          <div>
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

        <div className="plugin-card-footer">
          <span className={`plugin-price ${plugin.is_free ? 'free' : 'paid'}`}>
            {plugin.is_free ? 'Free' : `$${plugin.price_usd}`}
          </span>
          {plugin.version && (
            <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>
              v{plugin.version}
            </span>
          )}
        </div>
      </div>
    </Link>
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
