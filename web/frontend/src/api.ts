import axios from 'axios'

const http = axios.create({ baseURL: '/api/v1' })

http.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// ── Types ──────────────────────────────────────────────────────────────────

export type PluginType = 'Audio Unit' | 'VST 2' | 'VST 3'

export interface Plugin {
  id: number
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
  id: number
  email: string
  username: string
  created_at: string
}

export interface Preset {
  id: number
  plugin_id: number
  plugin_name: string | null
  name: string
  author: string
  genre: string
  description: string | null
  tags: string[]
  file_extension: string
  file_size_bytes: number | null
  is_downloadable: boolean
  is_community: boolean
  uploader_username: string | null
  favorited: boolean
  installed: boolean
  created_at: string
}

// ── Auth ───────────────────────────────────────────────────────────────────

export const register = (email: string, username: string, password: string) =>
  http.post<{ token: string; user: User }>('/auth/register', { email, username, password })
    .then((r) => r.data)

export const login = (loginId: string, password: string) =>
  http.post<{ token: string; user: User }>('/auth/login', { login: loginId, password })
    .then((r) => r.data)

export const getMe = () => http.get<User>('/auth/me').then((r) => r.data)

// ── Plugins ────────────────────────────────────────────────────────────────

export interface PluginFilters {
  q?: string
  type?: PluginType
  tags?: string
  is_free?: boolean
  sort?: 'name' | 'manufacturer' | 'newest'
}

export const getPlugins = (filters: PluginFilters = {}) => {
  const params: Record<string, string | number | boolean> = {}
  if (filters.q)                        params.q = filters.q
  if (filters.type)                     params.type = filters.type
  if (filters.tags)                     params.tags = filters.tags
  if (filters.is_free !== undefined)    params.is_free = filters.is_free
  if (filters.sort)                     params.sort = filters.sort
  return http.get<Plugin[]>('/plugins', { params }).then((r) => r.data)
}

export const getPlugin = (id: number) =>
  http.get<Plugin>(`/plugins/${id}`).then((r) => r.data)

// ── Plugin favorites ───────────────────────────────────────────────────────

export const getFavorites = () =>
  http.get<Plugin[]>('/favorites/plugins').then((r) => r.data)

export const addFavorite = (pluginId: number) =>
  http.post(`/favorites/plugins/${pluginId}`).then((r) => r.data)

export const removeFavorite = (pluginId: number) =>
  http.delete(`/favorites/plugins/${pluginId}`).then((r) => r.data)

// ── Presets ────────────────────────────────────────────────────────────────

export interface PresetFilters {
  plugin_id?: number
  genre?: string
  q?: string
  community?: boolean
}

export const getPresets = (filters: PresetFilters = {}) => {
  const params: Record<string, string | number | boolean> = {}
  if (filters.plugin_id !== undefined) params.plugin_id = filters.plugin_id
  if (filters.genre)                   params.genre = filters.genre
  if (filters.q)                       params.q = filters.q
  if (filters.community !== undefined) params.community = filters.community
  return http.get<Preset[]>('/presets', { params }).then((r) => r.data)
}

export const getPreset = (id: number) =>
  http.get<Preset>(`/presets/${id}`).then((r) => r.data)

export const getPresetDownloadUrl = (id: number) =>
  `${http.defaults.baseURL}/presets/${id}/download`

// ── Preset favorites ───────────────────────────────────────────────────────

export const getPresetFavorites = () =>
  http.get<Preset[]>('/favorites/presets').then((r) => r.data)

export const addPresetFavorite = (presetId: number) =>
  http.post(`/favorites/presets/${presetId}`).then((r) => r.data)

export const removePresetFavorite = (presetId: number) =>
  http.delete(`/favorites/presets/${presetId}`).then((r) => r.data)

// ── Preset installs (web → macOS queue) ───────────────────────────────────

export const queuePresetInstall = (presetId: number) =>
  http.post(`/installs/presets/${presetId}`, { status: 'queued' }).then((r) => r.data)

export const markPresetInstalled = (presetId: number) =>
  http.post(`/installs/presets/${presetId}`, { status: 'completed' }).then((r) => r.data)

// ── Preset upload ──────────────────────────────────────────────────────────

export const uploadPreset = (formData: FormData) =>
  http.post<Preset>('/presets', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then((r) => r.data)
