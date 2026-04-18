import { Routes, Route, Navigate } from 'react-router-dom'
import { useState } from 'react'
import Header from './components/Header'
import CatalogPage from './pages/CatalogPage'
import PluginDetailPage from './pages/PluginDetailPage'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import FavoritesPage from './pages/FavoritesPage'
import { useAuth } from './context/AuthContext'

export default function App() {
  const [search, setSearch] = useState('')
  const { user, loading } = useAuth()

  if (loading) return (
    <div className="spinner-wrap" style={{ minHeight: '100vh' }}>
      <div className="spinner" />
    </div>
  )

  return (
    <div className="app-layout">
      <Header searchValue={search} onSearch={setSearch} />
      <Routes>
        <Route path="/" element={<CatalogPage search={search} />} />
        <Route path="/plugin/:id" element={<PluginDetailPage />} />
        <Route path="/login" element={user ? <Navigate to="/" replace /> : <LoginPage />} />
        <Route path="/register" element={user ? <Navigate to="/" replace /> : <RegisterPage />} />
        <Route
          path="/favorites"
          element={user ? <FavoritesPage /> : <Navigate to="/login" replace />}
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </div>
  )
}
