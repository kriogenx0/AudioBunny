import { useState, FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { submitPlugin, PluginSubmission } from '../api'
import { useAuth } from '../context/AuthContext'

const FORMATS = ['AU', 'VST2', 'VST3'] as const

export default function SubmitPluginPage() {
  const { user } = useAuth()
  const navigate = useNavigate()

  const [name, setName]             = useState('')
  const [mfr, setMfr]               = useState('')
  const [category, setCategory]     = useState<'instrument' | 'effect'>('instrument')
  const [formats, setFormats]       = useState<string[]>(['VST3'])
  const [description, setDesc]      = useState('')
  const [version, setVersion]       = useState('')
  const [websiteUrl, setWebsite]    = useState('')
  const [githubRepo, setGithub]     = useState('')
  const [tags, setTags]             = useState('')
  const [isFree, setIsFree]         = useState(true)
  const [priceUsd, setPriceUsd]     = useState('')
  const [loading, setLoading]       = useState(false)
  const [error, setError]           = useState('')

  if (!user) {
    return (
      <div className="auth-page">
        <div className="auth-card" style={{ textAlign: 'center' }}>
          <h1 className="auth-title">Sign in to submit</h1>
          <p className="auth-sub">You need an account to submit plugins to the catalog.</p>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginTop: 24 }}>
            <button className="btn btn-primary" onClick={() => navigate('/login', { state: { next: '/submit-plugin' } })}>
              Sign in
            </button>
            <button className="btn btn-ghost" onClick={() => navigate('/register')}>
              Create account
            </button>
          </div>
        </div>
      </div>
    )
  }

  const toggleFormat = (f: string) =>
    setFormats(prev => prev.includes(f) ? prev.filter(x => x !== f) : [...prev, f])

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (formats.length === 0) { setError('Select at least one format.'); return }
    setLoading(true)
    setError('')
    try {
      const data: PluginSubmission = {
        name, manufacturer: mfr, category, formats, description,
        version, website_url: websiteUrl, github_repo: githubRepo, tags,
        is_free: isFree, price_usd: isFree ? null : (parseFloat(priceUsd) || null),
      }
      await submitPlugin(data)
      navigate('/', { state: { submitted: true } })
    } catch (err: any) {
      setError(err?.response?.data?.errors?.join(', ') ?? 'Submission failed.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="page" style={{ maxWidth: 640 }}>
      <h1 className="page-title">Submit a Plugin</h1>
      <p className="page-sub" style={{ marginBottom: 28 }}>
        Submissions are reviewed before appearing in the catalog.
      </p>

      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div className="form-group">
            <label className="form-label">Plugin Name *</label>
            <input className="form-input" value={name} onChange={e => setName(e.target.value)} required />
          </div>
          <div className="form-group">
            <label className="form-label">Developer / Manufacturer *</label>
            <input className="form-input" value={mfr} onChange={e => setMfr(e.target.value)} required />
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div className="form-group">
            <label className="form-label">Category *</label>
            <select className="filter-select" style={{ width: '100%', padding: '10px 14px' }}
              value={category} onChange={e => setCategory(e.target.value as any)}>
              <option value="instrument">Instrument</option>
              <option value="effect">Effect</option>
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Formats *</label>
            <div style={{ display: 'flex', gap: 8, paddingTop: 8 }}>
              {FORMATS.map(f => (
                <button key={f} type="button"
                  className={`chip ${formats.includes(f) ? 'active' : ''}`}
                  onClick={() => toggleFormat(f)}>{f}</button>
              ))}
            </div>
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Description</label>
          <textarea className="form-input" rows={3} value={description}
            onChange={e => setDesc(e.target.value)} style={{ resize: 'vertical' }} />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div className="form-group">
            <label className="form-label">Version</label>
            <input className="form-input" placeholder="e.g. 2.1.0" value={version}
              onChange={e => setVersion(e.target.value)} />
          </div>
          <div className="form-group">
            <label className="form-label">Tags (comma-separated)</label>
            <input className="form-input" placeholder="synth, wavetable, free" value={tags}
              onChange={e => setTags(e.target.value)} />
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div className="form-group">
            <label className="form-label">Website URL</label>
            <input className="form-input" type="url" placeholder="https://..." value={websiteUrl}
              onChange={e => setWebsite(e.target.value)} />
          </div>
          <div className="form-group">
            <label className="form-label">GitHub Repo (optional)</label>
            <input className="form-input" placeholder="owner/repo" value={githubRepo}
              onChange={e => setGithub(e.target.value)} />
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
            <input type="checkbox" checked={isFree} onChange={e => setIsFree(e.target.checked)} />
            <span style={{ fontSize: 14 }}>Free plugin</span>
          </label>
          {!isFree && (
            <div className="form-group" style={{ margin: 0, flex: 1 }}>
              <input className="form-input" type="number" min="0" step="0.01"
                placeholder="Price (USD)" value={priceUsd}
                onChange={e => setPriceUsd(e.target.value)} />
            </div>
          )}
        </div>

        {error && <p className="form-error">{error}</p>}

        <div style={{ display: 'flex', gap: 10 }}>
          <button type="button" className="btn btn-ghost" onClick={() => navigate(-1)}>Cancel</button>
          <button type="submit" className="btn btn-primary" disabled={loading}>
            {loading ? 'Submitting…' : 'Submit for Review'}
          </button>
        </div>
      </form>
    </div>
  )
}
