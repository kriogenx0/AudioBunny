import { Link, useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { useState } from 'react'

interface HeaderProps {
  searchValue?: string
  onSearch?: (v: string) => void
}

export default function Header({ searchValue = '', onSearch }: HeaderProps) {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()

  const handleSearch = (v: string) => {
    onSearch?.(v)
    if (location.pathname !== '/') navigate('/')
  }

  return (
    <header className="header">
      <Link to="/" className="header-logo">
        Audio<span>Bunny</span>
      </Link>

      <div className="header-search">
        <SearchIcon />
        <input
          type="text"
          placeholder="Search plugins, manufacturers…"
          value={searchValue}
          onChange={(e) => handleSearch(e.target.value)}
        />
      </div>

      <nav className="header-nav">
        <Link
          to="/"
          className={`nav-link ${location.pathname === '/' ? 'active' : ''}`}
        >
          Browse
        </Link>
        {user && (
          <Link
            to="/favorites"
            className={`nav-link ${location.pathname === '/favorites' ? 'active' : ''}`}
          >
            Favorites
          </Link>
        )}

        {user ? (
          <>
            <span className="nav-link" style={{ color: 'var(--text)', fontWeight: 500 }}>
              {user.username}
            </span>
            <button className="btn btn-ghost btn-sm" onClick={logout}>
              Sign out
            </button>
          </>
        ) : (
          <>
            <Link to="/login" className="btn btn-ghost btn-sm">Sign in</Link>
            <Link to="/register" className="btn btn-primary btn-sm">Sign up</Link>
          </>
        )}
      </nav>
    </header>
  )
}

function SearchIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
    </svg>
  )
}
