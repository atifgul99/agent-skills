'use client'

// Fixture for eval 3 (polish-modal-motion). Production-style modal with janky
// motion choices. Expected: routes to Jakub (production polish), specifies
// transform/opacity only, includes prefers-reduced-motion. NOT Jhey (no
// playful CSS art) and NOT Emil's gesture/spring depth (it's just a modal).

import * as Dialog from '@radix-ui/react-dialog'
import { useState } from 'react'

export function ConfirmDeleteDialog({ onConfirm }: { onConfirm: () => void }) {
  const [open, setOpen] = useState(false)

  return (
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Trigger className="rounded bg-red-500 px-4 py-2 text-white">Delete</Dialog.Trigger>
      <Dialog.Portal>
        {/* Janky: animates `all` properties, blunt 300ms ease — feels heavy */}
        <Dialog.Overlay
          className="fixed inset-0 bg-black/50 transition-all duration-300 ease-in-out
                     data-[state=open]:opacity-100 data-[state=closed]:opacity-0"
        />
        <Dialog.Content
          className="fixed left-1/2 top-1/2 w-96 -translate-x-1/2 -translate-y-1/2
                     rounded-lg bg-white p-6 transition-all duration-300 ease-in-out
                     data-[state=open]:scale-100 data-[state=closed]:scale-0"
        >
          <Dialog.Title className="text-lg font-semibold">Delete post?</Dialog.Title>
          <Dialog.Description className="mt-2 text-sm text-gray-600">This will delete the post.</Dialog.Description>
          <div className="mt-4 flex justify-end gap-2">
            <Dialog.Close className="rounded border px-3 py-1.5">Cancel</Dialog.Close>
            <button onClick={onConfirm} className="rounded bg-red-500 px-3 py-1.5 text-white">
              Delete
            </button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
