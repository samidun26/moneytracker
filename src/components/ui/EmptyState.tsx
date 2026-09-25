import type { ReactNode } from 'react'

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon: ReactNode
  title: string
  body?: string
  action?: ReactNode
}) {
  return (
    <div className="flex flex-col items-center px-8 py-12 text-center">
      <div className="text-label-3 mb-3 text-[44px] leading-none">{icon}</div>
      <p className="text-[20px] font-semibold">{title}</p>
      {body && <p className="text-label-2 mt-1.5 max-w-xs text-[15px] leading-5">{body}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  )
}
