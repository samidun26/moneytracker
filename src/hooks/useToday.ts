import { useEffect, useState } from 'react'
import { todayISO } from '@/lib/dates'

/** Today's date that rolls over at midnight and when the app is reopened. */
export function useToday(): string {
  const [today, setToday] = useState(todayISO)
  useEffect(() => {
    const check = () => setToday(todayISO())
    const t = setInterval(check, 60_000)
    document.addEventListener('visibilitychange', check)
    return () => {
      clearInterval(t)
      document.removeEventListener('visibilitychange', check)
    }
  }, [])
  return today
}
