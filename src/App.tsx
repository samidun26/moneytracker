import { useEffect, useState } from 'react'
import { createBrowserRouter, Navigate, RouterProvider, useNavigate, useSearchParams } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '@/db/db'
import { readString, writeString } from '@/lib/storage'
import { LedgerProvider } from '@/hooks/useLedger'
import { LockProvider } from '@/security/LockProvider'
import { ToastProvider } from '@/components/ui/Toast'
import { ConfirmProvider } from '@/components/ui/Confirm'
import { AppShell } from '@/components/AppShell'
import { ComposerProvider, useComposer } from '@/features/transactions/Composer'
import { HomePage } from '@/pages/HomePage'
import { ActivityPage } from '@/pages/ActivityPage'
import { InsightsPage } from '@/pages/InsightsPage'
import { MorePage } from '@/pages/MorePage'
import { AccountsPage } from '@/pages/AccountsPage'
import { AccountDetailPage } from '@/pages/AccountDetailPage'
import { BudgetsPage } from '@/pages/BudgetsPage'
import { RecurringPage } from '@/pages/RecurringPage'
import { CategoriesPage } from '@/pages/CategoriesPage'
import { SyncPage } from '@/pages/SyncPage'
import { SecurityPage } from '@/pages/SecurityPage'
import { DataPage } from '@/pages/DataPage'
import { OnboardingPage } from '@/pages/OnboardingPage'

/** Wraps routed screens: shows onboarding on first run, handles ?add= shortcuts and the "N" hotkey. */
function Root() {
  const accountCount = useLiveQuery(() => db.accounts.filter((a) => !a.deleted).count(), [])
  const [onboarded, setOnboarded] = useState(() => readString('duit.onboarded') === '1')
  const [params, setParams] = useSearchParams()
  const compose = useComposer()
  const navigate = useNavigate()

  // Devices that already have accounts (e.g. restored via sync) skip onboarding.
  useEffect(() => {
    if (!onboarded && accountCount && accountCount > 0) {
      writeString('duit.onboarded', '1')
      setOnboarded(true)
    }
  }, [accountCount, onboarded])

  useEffect(() => {
    const add = params.get('add')
    if (add === 'expense' || add === 'income' || add === 'transfer') {
      compose({ type: add })
      params.delete('add')
      setParams(params, { replace: true })
    }
  }, [params, setParams, compose])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement
      if (e.key.toLowerCase() === 'n' && !e.metaKey && !e.ctrlKey && !/INPUT|TEXTAREA|SELECT/.test(el.tagName) && !document.querySelector('[role=dialog]')) {
        e.preventDefault()
        compose()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [compose])

  if (accountCount === undefined) return null
  if (!onboarded && accountCount === 0)
    return (
      <OnboardingPage
        onDone={() => setOnboarded(true)}
        onRestore={() => {
          writeString('duit.onboarded', '1')
          setOnboarded(true)
          navigate('/more/sync')
        }}
      />
    )
  return <AppShell />
}

function Providers() {
  return (
    <ComposerProvider>
      <Root />
    </ComposerProvider>
  )
}

const router = createBrowserRouter([
  {
    element: <Providers />,
    children: [
      { path: '/', element: <HomePage /> },
      { path: '/activity', element: <ActivityPage /> },
      { path: '/insights', element: <InsightsPage /> },
      { path: '/more', element: <MorePage /> },
      { path: '/more/sync', element: <SyncPage /> },
      { path: '/more/security', element: <SecurityPage /> },
      { path: '/more/data', element: <DataPage /> },
      { path: '/accounts', element: <AccountsPage /> },
      { path: '/accounts/:id', element: <AccountDetailPage /> },
      { path: '/budgets', element: <BudgetsPage /> },
      { path: '/recurring', element: <RecurringPage /> },
      { path: '/categories', element: <CategoriesPage /> },
      { path: '*', element: <Navigate to="/" replace /> },
    ],
  },
])

export function App() {
  return (
    <LockProvider>
      <ToastProvider>
        <ConfirmProvider>
          <LedgerProvider>
            <RouterProvider router={router} />
          </LedgerProvider>
        </ConfirmProvider>
      </ToastProvider>
    </LockProvider>
  )
}
