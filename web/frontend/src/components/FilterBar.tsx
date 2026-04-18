import { PluginType } from '../api'

interface FilterBarProps {
  type: PluginType | ''
  onType: (v: PluginType | '') => void
  isFree: boolean | undefined
  onFree: (v: boolean | undefined) => void
  sort: 'name' | 'manufacturer' | 'newest'
  onSort: (v: 'name' | 'manufacturer' | 'newest') => void
  total: number
}

const TYPES: Array<{ label: string; value: PluginType | '' }> = [
  { label: 'All Types', value: '' },
  { label: 'Audio Unit', value: 'Audio Unit' },
  { label: 'VST 2', value: 'VST 2' },
  { label: 'VST 3', value: 'VST 3' },
]

export default function FilterBar({
  type, onType, isFree, onFree, sort, onSort, total,
}: FilterBarProps) {
  return (
    <div className="filters">
      <div className="filter-chips">
        {TYPES.map((t) => (
          <button
            key={t.value}
            className={`chip ${type === t.value ? 'active' : ''}`}
            onClick={() => onType(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      <button
        className={`chip ${isFree === true ? 'active' : ''}`}
        onClick={() => onFree(isFree === true ? undefined : true)}
      >
        Free only
      </button>

      <div className="filters-right">
        <span className="results-count">{total} plugin{total !== 1 ? 's' : ''}</span>
        <select
          className="filter-select"
          value={sort}
          onChange={(e) => onSort(e.target.value as typeof sort)}
        >
          <option value="name">A–Z</option>
          <option value="manufacturer">By manufacturer</option>
          <option value="newest">Newest first</option>
        </select>
      </div>
    </div>
  )
}
