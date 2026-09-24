import { useEffect, useRef, useState } from 'react'

/** Measure an element's width so SVG charts render crisp text at 1:1 scale. */
export function useWidth<T extends HTMLElement>(initial = 340) {
  const ref = useRef<T>(null)
  const [width, setWidth] = useState(initial)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const ro = new ResizeObserver(([e]) => setWidth(Math.round(e.contentRect.width)))
    ro.observe(el)
    setWidth(Math.round(el.getBoundingClientRect().width) || initial)
    return () => ro.disconnect()
  }, [initial])
  return [ref, width] as const
}
