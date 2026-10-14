export const TBA_API_ROOT = 'https://www.thebluealliance.com/api/v3'

const allowedPathPatterns = [
  /^status$/,
  /^districts\/\d{4}$/,
  /^events\/\d{4}\/simple$/,
  /^district\/\d{4}[a-z0-9]+\/teams\/simple$/,
  /^event\/[a-z0-9]+\/teams\/simple$/,
  /^team\/frc\d+\/media\/\d{4}$/,
]

export function isSupportedTbaPath(path: string): boolean {
  return allowedPathPatterns.some((pattern) => pattern.test(path))
}

export function requestTba(path: string, apiKey: string): Promise<Response> {
  return fetch(`${TBA_API_ROOT}/${path}`, {
    headers: {
      'X-TBA-Auth-Key': apiKey,
      Accept: 'application/json',
    },
  })
}
