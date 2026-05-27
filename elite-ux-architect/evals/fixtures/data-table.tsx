'use client'

// Fixture for eval 5 (router-discipline-pure-data-table). Intentionally
// boring: read-only table, no motion, no forms, no modals. The reviewer
// should NOT load 07 (motion), 03's modal/form sections, 05 (landing
// patterns), or 09 (creative arsenal). Just 10 + 06 + 11 — and maybe 02
// if they flag the gray-500 hardcoded color.

import { useQuery } from '@tanstack/react-query'

type Row = { id: string; name: string; postsThisWeek: number; lastActive: string }

export function MembersTable({ workspaceId }: { workspaceId: string }) {
  const { data, isLoading } = useQuery<Row[]>({
    queryKey: ['members', workspaceId],
    queryFn: () => fetch(`/api/workspaces/${workspaceId}/members`).then((r) => r.json()),
  })

  if (isLoading) return <div className="p-4 text-sm text-gray-500">Loading members…</div>
  if (!data || data.length === 0) return <div className="p-4 text-sm text-gray-500">No members yet.</div>

  return (
    <table className="w-full border-collapse">
      <thead>
        <tr className="border-b text-left text-sm text-gray-500">
          <th className="py-2">Member</th>
          <th className="py-2">Posts this week</th>
          <th className="py-2">Last active</th>
        </tr>
      </thead>
      <tbody>
        {data.map((row) => (
          <tr key={row.id} className="border-b">
            <td className="py-3 text-sm">{row.name}</td>
            <td className="py-3 text-sm tabular-nums">{row.postsThisWeek}</td>
            <td className="py-3 text-sm text-gray-500">{row.lastActive}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
