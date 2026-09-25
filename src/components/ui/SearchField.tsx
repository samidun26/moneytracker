import { Search, X } from 'lucide-react'

export function SearchField({
  value,
  onChange,
  placeholder = 'Search',
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <label className="bg-fill flex h-9 items-center gap-1.5 rounded-[10px] px-2">
      <Search className="text-label-2 size-[18px] shrink-0" strokeWidth={2.2} aria-hidden />
      <input
        type="search"
        inputMode="search"
        enterKeyHint="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
        className="placeholder:text-label-2 min-w-0 flex-1 bg-transparent text-[17px] outline-none [&::-webkit-search-cancel-button]:hidden"
      />
      {value && (
        <button type="button" aria-label="Clear search" onClick={() => onChange('')} className="text-label-2">
          <X className="bg-label-3 text-surface size-4 rounded-full p-0.5" strokeWidth={3} />
        </button>
      )}
    </label>
  )
}
