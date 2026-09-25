import { ChartPie, Ellipsis, House, Plus, ReceiptText, type LucideIcon } from 'lucide-react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { cn } from '@/lib/cn'
import { useComposer } from '@/features/transactions/Composer'

const TABS: Array<{ to: string; label: string; icon: LucideIcon; end?: boolean }> = [
  { to: '/', label: 'Home', icon: House, end: true },
  { to: '/activity', label: 'Activity', icon: ReceiptText },
  { to: '/insights', label: 'Insights', icon: ChartPie },
  { to: '/more', label: 'More', icon: Ellipsis },
]

/** Tab bar on phones, sidebar on wide screens. The + button opens the composer everywhere. */
export function AppShell() {
  const compose = useComposer()
  const { pathname } = useLocation()
  const moreActive = pathname.startsWith('/more') || /^\/(accounts|budgets|recurring|categories|settings)/.test(pathname)

  return (
    <div className="md:flex">
      {/* Sidebar (tablet / desktop) */}
      <aside className="bg-surface/60 hairline-r sticky top-0 hidden h-dvh w-60 shrink-0 flex-col gap-1 px-3 pt-6 md:flex">
        <div className="mb-5 flex items-center gap-2.5 px-2">
          <img src="/favicon.svg" alt="" className="size-8" />
          <span className="text-[20px] font-bold tracking-tight">Duit</span>
        </div>
        <button
          type="button"
          onClick={() => compose()}
          className="press bg-tint-fill text-on-tint mb-4 flex h-10 items-center justify-center gap-1.5 rounded-[10px] text-[15px] font-semibold"
        >
          <Plus className="size-5" strokeWidth={2.6} /> Add transaction
          <kbd className="ml-1 rounded bg-white/20 px-1.5 text-[11px] font-medium">N</kbd>
        </button>
        {TABS.map((t) => (
          <NavLink
            key={t.to}
            to={t.to}
            end={t.end}
            className={({ isActive }) =>
              cn(
                'flex h-10 items-center gap-3 rounded-[10px] px-3 text-[15px] font-medium',
                (isActive || (t.to === '/more' && moreActive)) ? 'bg-tint-soft text-tint' : 'text-label hover:bg-fill',
              )
            }
          >
            <t.icon className="size-5" strokeWidth={2} />
            {t.label}
          </NavLink>
        ))}
      </aside>

      <div className="min-w-0 flex-1">
        <Outlet />
      </div>

      {/* Tab bar (phone) */}
      <nav
        aria-label="Main"
        className="glass hairline-t pb-safe fixed inset-x-0 bottom-0 z-40 md:hidden"
      >
        <div className="mx-auto grid h-[52px] max-w-md grid-cols-5 items-stretch">
          {TABS.slice(0, 2).map((t) => (
            <Tab key={t.to} {...t} forceActive={false} />
          ))}
          <div className="flex items-center justify-center">
            <button
              type="button"
              aria-label="Add transaction"
              onClick={() => compose()}
              className="press bg-tint-fill text-on-tint flex size-11 items-center justify-center rounded-full shadow-[0_4px_14px_rgb(88_86_214/0.4)]"
            >
              <Plus className="size-6" strokeWidth={2.8} />
            </button>
          </div>
          {TABS.slice(2).map((t) => (
            <Tab key={t.to} {...t} forceActive={t.to === '/more' && moreActive} />
          ))}
        </div>
      </nav>
    </div>
  )
}

function Tab({ to, label, icon: Icon, end, forceActive }: { to: string; label: string; icon: LucideIcon; end?: boolean; forceActive: boolean }) {
  return (
    <NavLink
      to={to}
      end={end}
      className={({ isActive }) =>
        cn(
          'flex flex-col items-center justify-center gap-0.5 pt-1 text-[10px] font-medium',
          isActive || forceActive ? 'text-tint' : 'text-label-2',
        )
      }
    >
      <Icon className="size-6" strokeWidth={1.9} aria-hidden />
      {label}
    </NavLink>
  )
}
