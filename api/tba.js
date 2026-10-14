import { isSupportedTbaPath, requestTba } from '../server/tbaProxy.js'

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    response.setHeader('Allow', 'GET')
    return response.status(405).json({ error: 'Only GET requests are supported.' })
  }

  const apiKey = process.env.TBA_API_KEY
  if (!apiKey) {
    return response.status(503).json({
      error: 'The server is missing its TBA_API_KEY environment variable.',
    })
  }

  const path = typeof request.query.path === 'string' ? request.query.path : ''
  if (!isSupportedTbaPath(path)) {
    return response.status(400).json({ error: 'That The Blue Alliance request is not supported.' })
  }

  try {
    const upstream = await requestTba(path, apiKey)

    response.status(upstream.status)
    response.setHeader('Content-Type', upstream.headers.get('content-type') || 'application/json')
    response.setHeader('Cache-Control', 'public, s-maxage=3600, stale-while-revalidate=86400')
    return response.send(await upstream.text())
  } catch {
    return response.status(502).json({ error: 'The Blue Alliance could not be reached. Please try again.' })
  }
}
