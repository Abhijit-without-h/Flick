import { cn } from '../../lib/utils'

export function Badge({ className, children, ...props }) {
  return (
    <span
      className={cn(
        'inline-flex items-center border border-[var(--rule)] px-2.5 py-1 font-mono text-[0.65rem] uppercase tracking-[0.18em] text-[var(--muted)]',
        className,
      )}
      {...props}
    >
      {children}
    </span>
  )
}
