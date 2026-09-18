import { useEffect } from 'react'
import { ArrowDownRight } from 'lucide-react'
import HeroCanvas from './components/HeroCanvas'
import { Button } from './components/ui/button'
import { Badge } from './components/ui/badge'
import { RELEASE } from './lib/utils'
import { gsap, registerEffects, prefersReducedMotion, ScrollTrigger } from './lib/gsap-effects'

const KEYS = [
  { chord: '⌥ Space', action: 'Summon' },
  { chord: '↓ ↑', action: 'Move' },
  { chord: '↩', action: 'Open' },
  { chord: '⌘ ↩', action: 'Reveal' },
  { chord: '⌘ K', action: 'Actions' },
  { chord: 'Esc', action: 'Dismiss' },
]

const VERSUS = [
  { native: 'Spins a window', flick: 'Panel already exists' },
  { native: 'Whole-disk Spotlight index', flick: 'RAM catalog. Apps first.' },
  { native: 'Web hits, Siri, mail, junk', flick: 'Apps, three folders, commands' },
  { native: 'Ranks whatever mdquery returns', flick: 'Fuzzy + what you actually open' },
  { native: '⌘ Space, same as everyone', flick: '⌥ Space. Spotlight stays.' },
]

const SPEEDS = [
  { n: '<16 ms', d: 'Hotkey to first pixel. The HUD is pre-created, hidden, then ordered in.' },
  { n: '~2 ms', d: 'Warm app recatalog. Cold scan of Applications is under 100 ms, then cached.' },
  { n: '~17 ms', d: 'Desktop, Documents, Downloads indexed in the background. Apps are already searchable.' },
  { n: '0 %', d: 'Idle CPU after launch. Clipboard watch is a quiet timer, not a Spotlight daemon.' },
]

export default function App() {
  useEffect(() => {
    registerEffects()
    if (prefersReducedMotion()) return

    const hero = gsap.timeline({ delay: 0.15 })
    hero.inkStamp('.hero-stamp', { stagger: 0.08 })

    ScrollTrigger.batch('.proof-item', {
      onEnter: batch => gsap.effects.rise(batch, { stagger: 0.06 }),
      once: true,
    })
    ScrollTrigger.batch('.key-row', {
      onEnter: batch => gsap.effects.press(batch, { stagger: 0.05 }),
      once: true,
    })
    ScrollTrigger.batch('.speed-cell', {
      onEnter: batch => gsap.effects.rise(batch, { stagger: 0.05 }),
      once: true,
    })
    ScrollTrigger.batch('.vs-row', {
      onEnter: batch => gsap.effects.press(batch, { stagger: 0.04 }),
      once: true,
    })
    ScrollTrigger.batch('.dl-block', {
      onEnter: batch => gsap.effects.inkStamp(batch),
      once: true,
    })
  }, [])

  return (
    <>
      <div className="grain" aria-hidden="true" />
      <header className="fixed inset-x-0 top-0 z-30">
        <nav className="mx-auto flex max-w-6xl items-center justify-between px-5 py-4 md:px-8">
          <a href="#top" className="flex items-center gap-3 text-[var(--ink)] no-underline">
            <img src={`${import.meta.env.BASE_URL}brand/logo.png`} alt="" width={36} height={36} className="h-9 w-9 object-contain" />
            <span className="font-mono text-[0.7rem] uppercase tracking-[0.28em]">Flick</span>
          </a>
          <div className="flex items-center gap-6">
            <a href="#versus" className="hidden font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--ink)] no-underline md:inline">
              Versus
            </a>
            <a href="#brag" className="hidden font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--ink)] no-underline md:inline">
              Reel
            </a>
            <a href="#keys" className="hidden font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--ink)] no-underline md:inline">
              Keys
            </a>
            <Button asChild size="sm">
              <a href={RELEASE.dmg}>Download</a>
            </Button>
          </div>
        </nav>
      </header>

      <main id="main">
        <section id="top" className="relative h-dvh min-h-[640px] overflow-hidden">
          <HeroCanvas />
          <div className="pointer-events-none absolute inset-0 z-10 flex flex-col justify-end bg-gradient-to-t from-[var(--paper)] from-15% via-[var(--paper)]/40 to-transparent">
            <div className="mx-auto w-full max-w-6xl px-5 pb-16 pt-32 md:px-8 md:pb-20">
              <Badge className="hero-stamp mb-6 bg-[var(--paper)]/80">macOS 14 · Apple Silicon</Badge>
              <h1 className="hero-stamp display mb-4 max-w-3xl text-[clamp(3.4rem,11vw,8.5rem)] leading-[0.86] font-semibold tracking-[-0.03em] text-[var(--ink)]">
                Option+Space.
              </h1>
              <p className="hero-stamp mb-8 max-w-lg font-mono text-sm leading-relaxed text-[var(--muted)]">
                Faster than Spotlight because it does less. The panel is already in memory. Move the cursor to develop the print.
              </p>
              <div className="hero-stamp pointer-events-auto flex flex-wrap gap-3">
                <Button asChild size="lg">
                  <a href={RELEASE.dmg}>
                    Download for Mac
                    <ArrowDownRight className="h-4 w-4" aria-hidden="true" />
                  </a>
                </Button>
                <Button asChild variant="outline" size="lg">
                  <a href="#proof">How it works</a>
                </Button>
              </div>
            </div>
          </div>
        </section>

        <section id="versus" className="border-t border-[var(--rule)]">
          <div className="mx-auto max-w-6xl px-5 py-20 md:px-8">
            <p className="mb-3 font-mono text-[0.65rem] uppercase tracking-[0.22em] text-[var(--muted)]">⌘ Space vs ⌥ Space</p>
            <h2 className="display mb-4 max-w-3xl text-5xl font-semibold tracking-tight md:text-7xl">Spotlight searches the Mac. Flick searches what you launch.</h2>
            <p className="mb-14 max-w-xl text-sm leading-relaxed text-[var(--muted)]">
              Native search is a disk-wide index plus suggestions. Flick is a resident HUD over a tiny catalog. That is why it feels instant.
            </p>
            <div className="mb-4 hidden grid-cols-2 gap-8 font-mono text-[0.65rem] uppercase tracking-[0.18em] text-[var(--muted)] md:grid">
              <span>Spotlight</span>
              <span>Flick</span>
            </div>
            <ul className="divide-y divide-[var(--rule)] border-y border-[var(--rule)]">
              {VERSUS.map(row => (
                <li key={row.native} className="vs-row grid gap-2 py-5 md:grid-cols-2 md:gap-8">
                  <span className="text-sm text-[var(--muted)] line-through decoration-[var(--rule)] md:text-base">{row.native}</span>
                  <span className="display text-2xl leading-tight md:text-3xl">{row.flick}</span>
                </li>
              ))}
            </ul>
          </div>
          <div className="border-t border-[var(--rule)]">
            <div className="mx-auto grid max-w-6xl md:grid-cols-4">
              {SPEEDS.map(item => (
                <article key={item.n} className="speed-cell border-b border-[var(--rule)] px-5 py-10 md:border-r md:border-b-0 md:px-8 last:md:border-r-0">
                  <p className="display mb-3 text-4xl font-semibold tracking-tight md:text-5xl">{item.n}</p>
                  <p className="text-sm leading-relaxed text-[var(--muted)]">{item.d}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="brag" className="border-t border-[var(--rule)] px-5 py-20 md:px-8">
          <div className="mx-auto max-w-6xl">
            <p className="mb-3 font-mono text-[0.65rem] uppercase tracking-[0.22em] text-[var(--muted)]">Reel</p>
            <h2 className="display mb-10 text-5xl font-semibold tracking-tight md:text-6xl">The brag.</h2>
            <video
              className="w-full border border-[var(--rule)] bg-[var(--paper)]"
              poster={`${import.meta.env.BASE_URL}brag.jpg`}
              controls
              playsInline
              preload="metadata"
            >
              <source src={`${import.meta.env.BASE_URL}brag.mp4`} type="video/mp4" />
            </video>
          </div>
        </section>

        <section id="proof" className="border-t border-[var(--rule)]">
          <div className="mx-auto grid max-w-6xl gap-0 md:grid-cols-3">
            {[
              { n: '01', t: 'Apps first', d: 'Indexed from Applications and published before files. Type three letters. Return.' },
              { n: '02', t: 'A known catalog', d: 'Desktop, Documents, Downloads. No full-disk Spotlight junk.' },
              { n: '03', t: 'Commands', d: 'Calculator, quit, kill, sleep, lock, trash, clipboard — from the same field.' },
            ].map(item => (
              <article
                key={item.n}
                className="proof-item border-b border-[var(--rule)] px-5 py-12 md:border-r md:border-b-0 md:px-8 last:md:border-r-0"
              >
                <p className="mb-6 font-mono text-[0.65rem] uppercase tracking-[0.22em] text-[var(--muted)]">{item.n}</p>
                <h2 className="display mb-3 text-3xl font-semibold tracking-tight">{item.t}</h2>
                <p className="text-sm leading-relaxed text-[var(--muted)]">{item.d}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="keys" className="border-t border-[var(--rule)] px-5 py-20 md:px-8">
          <div className="mx-auto max-w-6xl">
            <p className="mb-3 font-mono text-[0.65rem] uppercase tracking-[0.22em] text-[var(--muted)]">Specimen</p>
            <h2 className="display mb-12 text-5xl font-semibold tracking-tight md:text-6xl">The press.</h2>
            <ul className="divide-y divide-[var(--rule)] border-y border-[var(--rule)]">
              {KEYS.map(row => (
                <li key={row.chord} className="key-row flex items-baseline justify-between gap-6 py-5">
                  <span className="font-mono text-sm tracking-wide md:text-base">{row.chord}</span>
                  <span className="display text-2xl italic md:text-3xl">{row.action}</span>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section id="download" className="border-t border-[var(--rule)]">
          <div className="dl-block mx-auto max-w-6xl px-5 py-24 md:px-8">
            <p className="mb-3 font-mono text-[0.65rem] uppercase tracking-[0.22em] text-[var(--muted)]">Edition 1.0.1</p>
            <h2 className="display mb-4 max-w-xl text-5xl font-semibold tracking-tight md:text-7xl">Take a copy.</h2>
            <p className="mb-10 max-w-lg text-sm text-[var(--muted)]">
              Drag Flick into Applications. First launch: right-click → Open. The build is ad-hoc signed, not notarized.
            </p>
            <div className="flex flex-wrap gap-3">
              <Button asChild size="lg">
                <a href={RELEASE.dmg}>Flick-1.0.1.dmg</a>
              </Button>
              <Button asChild variant="outline" size="lg">
                <a href={RELEASE.zip}>Zip</a>
              </Button>
              <Button asChild variant="ghost" size="lg">
                <a href={RELEASE.repo}>Source</a>
              </Button>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-[var(--rule)] px-5 py-8 md:px-8">
        <div className="mx-auto flex max-w-6xl flex-col gap-3 font-mono text-[0.65rem] uppercase tracking-[0.16em] text-[var(--muted)] md:flex-row md:justify-between">
          <span>Flick · native macOS</span>
          <a href={RELEASE.page} className="text-[var(--ink)] no-underline">
            All releases
          </a>
        </div>
      </footer>
    </>
  )
}
