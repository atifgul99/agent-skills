'use client'

// Fixture for eval 2 (review-dashboard-pr). Seeded with a mix of real issues
// (some Critical, some Important, some Opportunity) and one trap that LOOKS
// Critical but is actually only Opportunity — to test severity calibration.

import { useEffect, useState } from 'react'

export function Dashboard({ workspaceId }: { workspaceId: string }) {
  const [stats, setStats] = useState<{ posts: number; engagement: number } | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetch(`/api/workspaces/${workspaceId}/stats`)
      .then((r) => r.json())
      .then(setStats)
      .finally(() => setIsLoading(false))
  }, [workspaceId])

  // Trap: this button has no `focus-visible:ring-*` AND no `outline-none`.
  // Browser default ring still works. Should be 🟢 Opportunity, NOT 🔴 Critical.
  // An over-eager reviewer will flag this as "keyboard inaccessible".
  return (
    <div className="flex flex-col gap-4 p-6">
      <h1 className="text-2xl font-bold">Dashboard</h1>

      {/* Critical: missing empty state — only handles loading + populated */}
      {isLoading ? (
        <div className="h-screen">Loading...</div>
      ) : (
        <div className="grid grid-cols-3 gap-4">
          <div className="rounded-lg bg-white p-4 shadow transition-all">
            <p className="text-sm text-gray-500">Posts</p>
            <p className="text-3xl">{stats?.posts}</p>
          </div>
          <div className="rounded-lg bg-white p-4 shadow transition-all">
            <p className="text-sm text-gray-500">Engagement</p>
            <p className="text-3xl">{stats?.engagement}%</p>
          </div>
        </div>
      )}

      {/* Critical: <div onClick> for primary action — keyboard blocked */}
      <div
        onClick={() => fetch(`/api/workspaces/${workspaceId}/refresh`, { method: 'POST' })}
        className="cursor-pointer rounded bg-blue-500 px-4 py-2 text-white"
      >
        Refresh stats
      </div>

      {/* Important: hardcoded user-facing string + raw palette + h-screen */}
      <p className="text-red-500">Last sync failed at 3:47 PM</p>

      {/* Important: <img> with no width/height */}
      <img src="/screenshot.png" alt="Latest post preview" className="mt-4" />
    </div>
  )
}
