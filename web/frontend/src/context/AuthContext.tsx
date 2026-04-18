import {
  createContext,
  useContext,
  useState,
  useEffect,
  ReactNode,
} from 'react'
import { User, getMe } from '../api'

interface AuthState {
  user: User | null
  token: string | null
  loading: boolean
  setToken: (token: string) => void
  logout: () => void
}

const AuthContext = createContext<AuthState>(null!)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setTokenState] = useState<string | null>(
    () => localStorage.getItem('token')
  )
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(!!localStorage.getItem('token'))

  useEffect(() => {
    if (!token) {
      setUser(null)
      setLoading(false)
      return
    }
    setLoading(true)
    getMe()
      .then(setUser)
      .catch(() => {
        localStorage.removeItem('token')
        setTokenState(null)
      })
      .finally(() => setLoading(false))
  }, [token])

  const setToken = (t: string) => {
    localStorage.setItem('token', t)
    setTokenState(t)
  }

  const logout = () => {
    localStorage.removeItem('token')
    setTokenState(null)
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, token, loading, setToken, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
