import { motion } from 'motion/react'
import type { HTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/utils'

type Drag =
  | 'onAnimationStart' | 'onAnimationEnd' | 'onAnimationIteration'
  | 'onDragStart' | 'onDrag' | 'onDragEnd'

interface BentoTileProps extends Omit<HTMLAttributes<HTMLDivElement>, Drag> {
  children: ReactNode
  delay?: number
  hover?: boolean
}

/**
 * Wagevo bento tile — spring-in entrance, hover lift, glass-tile cursor rim.
 * Drop into any grid cell, use `delay` to stagger entrance.
 */
export function BentoTile({ children, className, delay = 0, hover = true, ...props }: BentoTileProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 260, damping: 22, delay }}
      whileHover={hover ? { y: -2, transition: { type: 'spring', stiffness: 400, damping: 28 } } : undefined}
      className={cn('wg-card glass-tile', hover && 'wg-card-hover', className)}
      {...props}
    >
      {children}
    </motion.div>
  )
}
