import vue from '@vitejs/plugin-vue'
import { defineConfig, loadEnv, type Plugin } from 'vite'
import { isSupportedTbaPath, requestTba } from './server/tbaProxy.js'

function localTbaProxy(apiKey: string): Plugin {
  const middleware = async (request: { method?: string; url?: string }, response: {
    statusCode: number
    setHeader(name: string, value: string): void
    end(body?: string): void
  }) => {
    if (request.method !== 'GET') {
      response.setHeader('Allow', 'GET')
      response.statusCode = 405
      response.end(JSON.stringify({ error: 'Only GET requests are supported.' }))
      return
    }

    if (!apiKey) {
      response.statusCode = 503
      response.setHeader('Content-Type', 'application/json')
      response.end(JSON.stringify({ error: 'Set TBA_API_KEY in .env.local to load TBA data locally.' }))
      return
    }

    const url = new URL(request.url || '/', 'http://localhost')
    const path = url.searchParams.get('path') || ''
    if (!isSupportedTbaPath(path)) {
      response.statusCode = 400
      response.setHeader('Content-Type', 'application/json')
      response.end(JSON.stringify({ error: 'That The Blue Alliance request is not supported.' }))
      return
    }

    try {
      const upstream = await requestTba(path, apiKey)
      response.statusCode = upstream.status
      response.setHeader('Content-Type', upstream.headers.get('content-type') || 'application/json')
      response.setHeader('Cache-Control', 'public, s-maxage=3600, stale-while-revalidate=86400')
      response.end(await upstream.text())
    } catch {
      response.statusCode = 502
      response.setHeader('Content-Type', 'application/json')
      response.end(JSON.stringify({ error: 'The Blue Alliance could not be reached. Please try again.' }))
    }
  }

  return {
    name: 'team-recall-tba-proxy',
    configureServer(server) {
      server.middlewares.use('/api/tba', middleware)
    },
    configurePreviewServer(server) {
      server.middlewares.use('/api/tba', middleware)
    },
  }
}

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const apiKey = loadEnv(mode, process.cwd(), 'TBA_').TBA_API_KEY
  return {
    plugins: [vue(), localTbaProxy(apiKey)],
  }
})
