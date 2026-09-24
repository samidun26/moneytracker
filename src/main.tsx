import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/index.css'
import { App } from './App'
import { applyTheme } from './lib/theme'
import { bootstrap } from './bootstrap'
import { registerServiceWorker } from './pwa'

applyTheme()
registerServiceWorker()
void bootstrap()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)

if (import.meta.env.DEV) {
  void import('./dev/demo').then((m) => {
    ;(window as unknown as { __duitDemo: typeof m }).__duitDemo = m
  })
}
