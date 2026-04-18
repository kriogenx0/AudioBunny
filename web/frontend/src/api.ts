import axios from 'axios'

const http = axios.create({ baseURL: '/api' })

http.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// ── Types ──────────────────────────────────────────────────────────────────

export type PluginType = 'Audio Unit' | 'VST 2' | 'VST 3'

export interface Plugin {
  id: string
  name: string
  manufacturer: string
  plugin_type: PluginType
  description: string | null
  version: string | null
  tags: string | null
  thumbnail_url: string | null
  download_url: string | null
  file_size_bytes: number | null
  is_free: boolean
  price_usd: number | null
  created_at: string
  favorited: boolean
}

export interface User {
  id: string
  email: string
  username: string
  created_at: string
}

export interface Token {
  access_token: string
  token_type: string
}

// ── Auth ───────────────────────────────────────────────────────────────────

export const register = (email: string, username: string, password: string) =>
  http.post<User>('/auth/register', { email, username, password }).then((r) => r.data)

export const login = (username: string, password: string) => {
  const form = new URLSearchParams({ username, password })
  return http
    .post<Token>('/auth/login', form, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    })
    .then((r) => r.data)
}

export const getMe = () => http.get<User>('/auth/me').then((r) => r.data)

// ── Plugins ────────────────────────────────────────────────────────────────

export interface PluginFilters {
  q?: string
  type?: PluginType
  tags?: string
  is_free?: boolean
  sort?: 'name' | 'manufacturer' | 'newest'
  limit?: number
  offset?: number
}

export const getPlugins = (filters: PluginFilters = {}) => {
  const params: Record<string, string | number | boolean> = {}
  if (filters.q) params.q = filters.q
  if (filters.type) params.type = filters.type
  if (filters.tags) params.tags = filters.tags
  if (filters.is_free !== undefined) params.is_free = filters.is_free
  if (filters.sort) params.sort = filters.sort
  if (filters.limit !== undefined) params.limit = filters.limit
  if (filters.offset !== undefined) params.offset = filters.offset
  return http.get<Plugin[]>('/plugins', { params }).then((r) => r.data)
}

export const getPlugin = (id: string) =>
  http.get<Plugin>(`/plugins/${id}`).then((r) => r.data)

// ── Favorites ──────────────────────────────────────────────────────────────

export const getFavorites = () =>
  http.get<Plugin[]>('/favorites').then((r) => r.data)

export const addFavorite = (pluginId: string) =>
  http.post(`/favorites/${pluginId}`).then((r) => r.data)

export const removeFavorite = (pluginId: string) =>
  http.delete(`/favorites/${pluginId}`).then((r) => r.data)
