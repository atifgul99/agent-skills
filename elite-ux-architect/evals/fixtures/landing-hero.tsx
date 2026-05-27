// Fixture for eval 4 (redesign-landing-hero). A textbook 2018 SaaS hero:
// centered headline + subtitle + two buttons + abstract gradient blob.
// Every AI-tell in the book. Expected: Scan → Diagnose → Fix, with the
// Diagnose phase citing concrete tells from 06, and Fix proposing Bento 2.0
// or an anti-slop creative direction from 09 — not a from-scratch rebuild.

export function LandingHero() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-br from-purple-50 via-white to-blue-50 px-6 py-24">
      <div className="absolute left-1/2 top-0 h-96 w-96 -translate-x-1/2 rounded-full bg-purple-200 opacity-30 blur-3xl" />
      <div className="absolute right-0 top-1/3 h-64 w-64 rounded-full bg-blue-200 opacity-30 blur-3xl" />

      <div className="relative mx-auto max-w-4xl text-center">
        <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-purple-200 bg-white/60 px-4 py-1.5 text-sm font-medium text-purple-700 backdrop-blur">
          <span className="h-2 w-2 rounded-full bg-purple-500" />
          Now with AI
        </div>

        <h1 className="bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-5xl font-bold leading-tight text-transparent md:text-7xl">
          Unleash the power of your social presence
        </h1>

        <p className="mx-auto mt-6 max-w-2xl text-xl text-gray-600">
          Streamline your workflow with AI-powered tools that help you create, schedule, and analyze content
          effortlessly.
        </p>

        <div className="mt-10 flex items-center justify-center gap-4">
          <button className="rounded-lg bg-purple-600 px-6 py-3 font-semibold text-white shadow-lg shadow-purple-500/30 transition-all hover:scale-105">
            Get started free
          </button>
          <button className="rounded-lg border border-gray-300 bg-white px-6 py-3 font-semibold text-gray-700 transition-all hover:bg-gray-50">
            Watch demo
          </button>
        </div>

        <p className="mt-6 text-sm text-gray-500">No credit card required. 14-day free trial. Cancel anytime.</p>
      </div>
    </section>
  )
}
