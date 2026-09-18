import { Component } from 'react'
import HalftoneReveal from './HalftoneReveal'

class WebGLGuard extends Component {
  constructor(props) {
    super(props)
    this.state = { failed: false }
  }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  componentDidCatch() {}

  render() {
    if (this.state.failed) return this.props.fallback
    return this.props.children
  }
}

export default function HeroCanvas() {
  const src = `${import.meta.env.BASE_URL}brand/banner.jpg`
  const fallback = (
    <img src={src} alt="" className="h-full w-full object-cover" />
  )

  return (
    <WebGLGuard fallback={fallback}>
      <HalftoneReveal
        src={src}
        inkColor="#141414"
        paperColor="#f4efe4"
        mode="mono"
        dotDensity={90}
        angle={28}
        revealRadius={0.28}
        edge={0.72}
        follow={0.32}
        trigger="hover"
        borderRadius="0px"
        className="absolute inset-0 h-full w-full"
      />
    </WebGLGuard>
  )
}
