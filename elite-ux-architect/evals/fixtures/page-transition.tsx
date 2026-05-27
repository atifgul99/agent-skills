'use client'

// Fixture for eval 6 (router-discipline-motion-only). A page-transition
// animation with deliberately wrong timing (450ms is too long) and a
// blunt ease-in-out (no spring or custom curve). Expected: loads 07 +
// one designer reference, does NOT load 10 (this is not a code review),
// 03 (no patterns), 04 (no Tailwind questions), or 06 (no anti-pattern
// catalog needed — this is a motion-only audit).

import { motion, AnimatePresence } from 'framer-motion'

export function PageTransition({ pageKey, children }: { pageKey: string; children: React.ReactNode }) {
  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={pageKey}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -20 }}
        transition={{ duration: 0.45, ease: 'easeInOut' }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  )
}
