import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { getPlugins, PluginType } from '../api'
import FilterBar from '../components/FilterBar'
import PluginCard from '../components/PluginCard'

interface CatalogPageProps {
  search: string
}

export default function CatalogPage({ search }: CatalogPageProps) {
  const [type, setType] = useState<PluginType | ''>('')
  const [isFree, setIsFree] = useState<boolean | undefined>(undefined)
  const [sort, setSort] = useState<'name' | 'manufacturer' | 'newest'>('name')

  const { data: plugins = [], isLoading } = useQuery({
    queryKey: ['plugins', search, type, isFree, sort],
    queryFn: () =>
      getPlugins({
        q: search || undefined,
        type: type || undefined,
        is_free: isFree,
        sort,
        limit: 200,
      }),
  })

  return (
    <main className="page">
      <FilterBar
        type={type} onType={setType}
        isFree={isFree} onFree={setIsFree}
        sort={sort} onSort={setSort}
        total={plugins.length}
      />

      {isLoading ? (
        <div className="spinner-wrap"><div className="spinner" /></div>
      ) : plugins.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">🔍</span>
          <p className="empty-title">No plugins found</p>
          <p className="empty-desc">Try adjusting your search or filters.</p>
        </div>
      ) : (
        <div className="plugin-grid">
          {plugins.map((p) => <PluginCard key={p.id} plugin={p} />)}
        </div>
      )}
    </main>
  )
}
