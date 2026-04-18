import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { getFavorites } from '../api'
import { useAuth } from '../context/AuthContext'
import PluginCard from '../components/PluginCard'

export default function FavoritesPage() {
  const { user } = useAuth()
  const { data: favorites = [], isLoading } = useQuery({
    queryKey: ['favorites'],
    queryFn: getFavorites,
    enabled: !!user,
  })

  if (isLoading) return (
    <main className="page">
      <div className="spinner-wrap"><div className="spinner" /></div>
    </main>
  )

  return (
    <main className="page">
      <div className="page-header">
        <h1 className="page-title">Your Favorites</h1>
        <p className="page-sub">
          {favorites.length} plugin{favorites.length !== 1 ? 's' : ''} saved ·
          {' '}Synced to AudioBunny on macOS
        </p>
      </div>

      {favorites.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">♡</span>
          <p className="empty-title">No favorites yet</p>
          <p className="empty-desc">
            Browse the catalog and tap the heart icon to save plugins. They'll
            appear here and sync to your Mac.
          </p>
          <Link to="/" className="btn btn-primary" style={{ marginTop: 8 }}>
            Browse catalog
          </Link>
        </div>
      ) : (
        <div className="plugin-grid">
          {favorites.map((p) => <PluginCard key={p.id} plugin={p} />)}
        </div>
      )}
    </main>
  )
}
