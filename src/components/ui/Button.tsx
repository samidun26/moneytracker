import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/cn'

type Variant = 'filled' | 'tinted' | 'plain' | 'destructive' | 'gray'

export function Button({
  variant = 'filled',
  size = 'lg',
  block,
  className,
  children,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant
  size?: 'md' | 'lg'
  block?: boolean
  children: ReactNode
}) {
  return (
    <button
      type="button"
      {...rest}
      className={cn(
        'press inline-flex items-center justify-center gap-2 font-semibold disabled:opacity-40 disabled:active:scale-100',
        size === 'lg' ? 'h-[50px] rounded-[14px] px-5 text-[17px]' : 'h-9 rounded-full px-4 text-[15px]',
        block && 'w-full',
        variant === 'filled' && 'bg-tint-fill text-on-tint',
        variant === 'tinted' && 'bg-tint-soft text-tint',
        variant === 'gray' && 'bg-fill text-label',
        variant === 'plain' && 'text-tint',
        variant === 'destructive' && 'bg-negative-fill/15 text-negative',
        className,
      )}
    >
      {children}
    </button>
  )
}
