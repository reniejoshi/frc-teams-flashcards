const PAGE_SIZE = 500;
const MAX_TEAM_PAGES = 100;
const TEAM_CACHE_KEY = new Request(
    'https://frc-teams-flashcards-cache.invalid/all-teams',
);
const CACHE_SECONDS = 6 * 60 * 60;

export default {
    async fetch(request, env, context) {
        const url = new URL(request.url);

        if (request.method === 'OPTIONS') {
            return new Response(null, { status: 204, headers: corsHeaders() });
        }

        if (request.method !== 'GET' || url.pathname !== '/random-team') {
            return jsonResponse({ error: 'Not found' }, 404);
        }

        if (!env.TBA_API_KEY) {
            return jsonResponse({ error: 'Team service is not configured' }, 503);
        }

        try {
            const teams = await getTeams(env, context);
            if (teams.length === 0) {
                return jsonResponse({ error: 'No teams are available' }, 503);
            }

            const team = teams[Math.floor(Math.random() * teams.length)];
            return jsonResponse({
                team_number: team.team_number,
                nickname: team.nickname,
                name: team.name,
                key: team.key,
            });
        } catch {
            return jsonResponse({ error: 'Unable to load teams from TBA' }, 502);
        }
    },
};

async function getTeams(env, context) {
    const cache = caches.default;
    const cachedResponse = await cache.match(TEAM_CACHE_KEY);
    if (cachedResponse) {
        return cachedResponse.json();
    }

    const teams = [];
    for (let pageNumber = 0; pageNumber < MAX_TEAM_PAGES; pageNumber += 1) {
        const response = await fetch(
            `https://www.thebluealliance.com/api/v3/teams/${pageNumber}/simple`,
            { headers: { 'X-TBA-Auth-Key': env.TBA_API_KEY } },
        );

        if (!response.ok) {
            throw new Error(`TBA returned ${response.status}`);
        }

        const page = await response.json();
        if (!Array.isArray(page)) {
            throw new Error('TBA returned an invalid team page');
        }

        teams.push(...page);
        if (page.length < PAGE_SIZE) {
            const cachedTeams = new Response(JSON.stringify(teams), {
                headers: {
                    'Cache-Control': `public, max-age=${CACHE_SECONDS}`,
                    'Content-Type': 'application/json',
                },
            });
            context.waitUntil(cache.put(TEAM_CACHE_KEY, cachedTeams));
            return teams;
        }
    }

    throw new Error('TBA team pagination exceeded the configured limit');
}

function corsHeaders() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
    };
}

function jsonResponse(body, status = 200) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            ...corsHeaders(),
            'Cache-Control': 'no-store',
            'Content-Type': 'application/json',
        },
    });
}