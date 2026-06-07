import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  getAdminSubmissions, approvePlugin, rejectPlugin,
  approvePreset, rejectPreset,
} from '../api'
import { useAuth } from '../context/AuthContext'

export default function AdminPage() {
  const { user } = useAuth()
  const navigate = useNavigate()

  if (!user) { navigate('/login'); return null }
  if (!user.is_admin) {
    return (
      <div className="page" style={{ textAlign: 'center', paddingTop: 80 }}>
        <p style={{ color: 'var(--red)', fontSize: 16 }}>Access denied — admin only.</p>
      </div>
    )
  }

  return <AdminDashboard />
}

function AdminDashboard() {
  const qc = useQueryClient()
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin-submissions'],
    queryFn: getAdminSubmissions,
  })

  const act = async (fn: () => Promise<any>) => {
    await fn()
    qc.invalidateQueries({ queryKey: ['admin-submissions'] })
  }

  if (isLoading) return <div className="spinner-wrap"><div className="spinner" /></div>
  if (error) return <div className="page"><p className="form-error">Failed to load submissions.</p></div>

  const plugins = data?.plugins ?? []
  const presets = data?.presets ?? []
  const total = plugins.length + presets.length

  return (
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Admin — Submissions</h1>
        <p className="page-sub">{total} pending review</p>
      </div>

      {total === 0 && (
        <div className="empty-state">
          <span className="empty-icon">✓</span>
          <p className="empty-title">All clear</p>
          <p className="empty-desc">No pending submissions.</p>
        </div>
      )}

      {plugins.length > 0 && (
        <section style={{ marginBottom: 40 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>
            Plugins ({plugins.length})
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {plugins.map(p => (
              <SubmissionRow
                key={p.id}
                title={p.name}
                subtitle={`${p.manufacturer} · ${(p.formats ?? []).join(', ')}`}
                meta={`Submitted by ${p.submitted_by?.username ?? 'unknown'}`}
                detail={p.description ?? ''}
                onApprove={() => act(() => approvePlugin(p.id))}
                onReject={() => act(() => rejectPlugin(p.id))}
              />
            ))}
          </div>
        </section>
      )}

      {presets.length > 0 && (
        <section>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>
            Presets ({presets.length})
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {presets.map(p => (
              <SubmissionRow
                key={p.id}
                title={p.name}
                subtitle={`${p.plugin_name ?? '—'} · ${p.genre} · .${p.file_extension?.toUpperCase()}`}
                meta={`Uploaded by ${p.uploader_username ?? 'unknown'}`}
                detail={p.description ?? ''}
                onApprove={() => act(() => approvePreset(p.id))}
                onReject={() => act(() => rejectPreset(p.id))}
              />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}

function SubmissionRow({ title, subtitle, meta, detail, onApprove, onReject }: {
  title: string; subtitle: string; meta: string; detail: string
  onApprove: () => void; onReject: () => void
}) {
  const [expanded, setExpanded] = useState(false)
  return (
    <div style={{
      background: 'var(--surface)', border: '1px solid var(--border)',
      borderRadius: 10, padding: '14px 16px',
    }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 600, fontSize: 14 }}>{title}</div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 2 }}>{subtitle}</div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>{meta}</div>
          {expanded && detail && (
            <p style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 8, lineHeight: 1.5 }}>{detail}</p>
          )}
          {detail && (
            <button className="btn btn-ghost btn-sm" style={{ marginTop: 6, padding: '2px 8px' }}
              onClick={() => setExpanded(v => !v)}>
              {expanded ? 'Less' : 'More'}
            </button>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
          <button className="btn btn-primary btn-sm" onClick={onApprove}>Approve</button>
          <button className="btn btn-ghost btn-sm" style={{ color: 'var(--red)', borderColor: 'var(--red)' }}
            onClick={onReject}>Reject</button>
        </div>
      </div>
    </div>
  )
}
