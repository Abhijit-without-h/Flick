import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

let registered = false

export function registerEffects() {
  if (registered) return
  gsap.registerPlugin(ScrollTrigger)

  gsap.registerEffect({
    name: 'inkStamp',
    extendTimeline: true,
    defaults: { duration: 0.9, stagger: 0 },
    effect: (targets, config) =>
      gsap.from(targets, {
        opacity: 0,
        y: 28,
        rotate: -0.35,
        duration: config.duration,
        stagger: config.stagger,
        ease: 'power3.out',
      }),
  })

  gsap.registerEffect({
    name: 'rise',
    extendTimeline: true,
    defaults: { duration: 0.75, stagger: 0.05 },
    effect: (targets, config) =>
      gsap.from(targets, {
        y: 18,
        opacity: 0,
        duration: config.duration,
        stagger: config.stagger,
        ease: 'power2.out',
      }),
  })

  gsap.registerEffect({
    name: 'press',
    extendTimeline: true,
    defaults: { duration: 0.55, stagger: 0.04 },
    effect: (targets, config) =>
      gsap.from(targets, {
        scale: 0.96,
        opacity: 0,
        duration: config.duration,
        stagger: config.stagger,
        ease: 'back.out(1.4)',
      }),
  })

  registered = true
}

export function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export { gsap, ScrollTrigger }
