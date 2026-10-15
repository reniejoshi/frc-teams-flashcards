<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'

const season = new Date().getFullYear()

interface District {
  key: string
  abbreviation: string
  display_name: string
  year: number
}

interface EventSummary {
  key: string
  name: string
  district?: District | null
  city?: string | null
  state_prov?: string | null
  start_date?: string | null
}

interface TeamSummary {
  key: string
  team_number: number
  nickname?: string | null
  name?: string | null
  city?: string | null
  state_prov?: string | null
}

interface TeamMedia {
  type?: string
  media?: string
  direct_url?: string
  preferred?: boolean
  details?: Record<string, unknown>
}

const districts = ref<District[]>([])
const events = ref<EventSummary[]>([])
const teams = ref<TeamSummary[]>([])
const selectedDistrictKey = ref('')
const selectedEventKey = ref('')
const currentIndex = ref(0)
const teamAnswers = ref<Array<boolean | null>>([])
const sessionTeamCount = ref(0)
const loadingSources = ref(false)
const loadingTeams = ref(false)
const pageMessage = ref('')
const revealed = ref(false)
const roundComplete = ref(false)
const cardInstance = ref(0)
const logoFailed = ref(false)
const robotImage = ref('')
const robotLoading = ref(false)
let robotRequestId = 0
const robotImageCache = new Map<string, string>()

const currentTeam = computed(() => teams.value[currentIndex.value] ?? null)
const sessionCorrect = computed(() => teamAnswers.value.filter((answer) => answer === true).length)
const selectedSet = computed({
  get: () => selectedEventKey.value
    ? `event:${selectedEventKey.value}`
    : selectedDistrictKey.value
      ? `region:${selectedDistrictKey.value}`
      : '',
  set: (value: string) => {
    if (value.startsWith('event:')) {
      selectedEventKey.value = value.slice('event:'.length)
      selectedDistrictKey.value = ''
    } else if (value.startsWith('region:')) {
      selectedDistrictKey.value = value.slice('region:'.length)
      selectedEventKey.value = ''
    } else {
      selectedDistrictKey.value = ''
      selectedEventKey.value = ''
    }
    void loadTeams()
  },
})

const teamLocation = computed(() => {
  if (!currentTeam.value) return ''
  return [currentTeam.value.city, currentTeam.value.state_prov].filter(Boolean).join(', ')
})

const teamLogoUrl = computed(() =>
  currentTeam.value ? `https://www.thebluealliance.com/avatar/${season}/${currentTeam.value.key}.png` : '',
)

const teamInitials = computed(() => {
  const name = currentTeam.value?.nickname || currentTeam.value?.name || 'FRC'
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('')
})

async function tbaRequest<T>(path: string): Promise<T> {
  const response = await fetch(`/api/tba?path=${encodeURIComponent(path.replace(/^\//, ''))}`)
  if (!response.ok) {
    let detail = ''
    try {
      const body = (await response.json()) as { error?: string }
      detail = body.error ?? ''
    } catch {
      // Use the HTTP status if the proxy did not return JSON.
    }
    throw new Error(detail || `Could not load The Blue Alliance data (${response.status}). Please try again.`)
  }
  return (await response.json()) as T
}

async function loadSources() {
  loadingSources.value = true
  pageMessage.value = ''
  try {
    const [districtList, eventList] = await Promise.all([
      tbaRequest<District[]>(`/districts/${season}`),
      tbaRequest<EventSummary[]>(`/events/${season}/simple`),
    ])
    districts.value = [...districtList].sort((a, b) => a.display_name.localeCompare(b.display_name))
    events.value = [...eventList].sort((a, b) => a.name.localeCompare(b.name))

    if (selectedDistrictKey.value && !districtList.some((district) => district.key === selectedDistrictKey.value)) {
      selectedDistrictKey.value = ''
    }
    if (selectedEventKey.value && !eventList.some((event) => event.key === selectedEventKey.value)) {
      selectedEventKey.value = ''
    }
    if (
      selectedEventKey.value &&
      selectedDistrictKey.value &&
      !eventList.some(
        (event) => event.key === selectedEventKey.value && event.district?.key === selectedDistrictKey.value,
      )
    ) {
      selectedEventKey.value = ''
    }

    if (selectedEventKey.value || selectedDistrictKey.value) await loadTeams()
  } catch (error) {
    pageMessage.value = error instanceof Error ? error.message : 'Could not connect to The Blue Alliance.'
  } finally {
    loadingSources.value = false
  }
}

async function loadTeams() {
  robotRequestId += 1
  revealed.value = false
  roundComplete.value = false
  logoFailed.value = false
  robotImage.value = ''
  pageMessage.value = ''
  teams.value = []
  currentIndex.value = 0
  teamAnswers.value = []
  sessionTeamCount.value = 0
  const path = selectedEventKey.value
    ? `/event/${selectedEventKey.value}/teams/simple`
    : selectedDistrictKey.value
      ? `/district/${selectedDistrictKey.value}/teams/simple`
      : ''
  if (!path) return

  loadingTeams.value = true
  try {
    teams.value = (await tbaRequest<TeamSummary[]>(path)).sort(
      (a, b) => a.team_number - b.team_number,
    )
    sessionTeamCount.value = teams.value.length
    teamAnswers.value = Array.from({ length: teams.value.length }, () => null)
  } catch (error) {
    pageMessage.value = error instanceof Error ? error.message : 'Could not load teams.'
  } finally {
    loadingTeams.value = false
  }
}

async function loadRobotImage(team: TeamSummary) {
  const requestId = ++robotRequestId
  if (robotImageCache.has(team.key)) {
    robotImage.value = robotImageCache.get(team.key) ?? ''
    robotLoading.value = false
    return
  }
  robotImage.value = ''
  robotLoading.value = true
  try {
    const media = await tbaRequest<TeamMedia[]>(`/team/${team.key}/media/${season}`)
    if (requestId !== robotRequestId) return

    const candidates = media
      .filter((item) => !['avatar', 'youtube', 'cd-thread'].includes(item.type ?? ''))
      .map((item) => {
        const details = item.details ?? {}
        const image = details.base64Image
        const url = typeof image === 'string' && image.length > 0
          ? `data:image/png;base64,${image}`
          : item.direct_url?.startsWith('https://')
            ? item.direct_url
            : item.media?.startsWith('https://')
              ? item.media
              : ''
        return { url, preferred: item.preferred ?? false }
      })
      .filter((candidate) => candidate.url)
      .sort((a, b) => Number(b.preferred) - Number(a.preferred))
    robotImage.value = candidates[0]?.url ?? ''
    robotImageCache.set(team.key, robotImage.value)
  } catch {
    if (requestId !== robotRequestId) return
    robotImageCache.set(team.key, '')
  } finally {
    if (requestId === robotRequestId) robotLoading.value = false
  }
}

function answerCard(correct: boolean) {
  if (!currentTeam.value) return
  teamAnswers.value[currentIndex.value] = correct
  if (teamAnswers.value.every((answer) => answer !== null)) {
    revealed.value = false
    roundComplete.value = true
    cardInstance.value += 1
    return
  }
  goToCard(currentIndex.value + 1)
}

function goToCard(index: number) {
  if (!teams.value.length) return
  currentIndex.value = (index + teams.value.length) % teams.value.length
  revealed.value = false
  cardInstance.value += 1
}

function shuffleTeams() {
  if (teams.value.length < 2) return
  const answersByTeam = new Map(teams.value.map((team, index) => [team.key, teamAnswers.value[index] ?? null]))
  const shuffled = [...teams.value]
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1))
    ;[shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]]
  }
  teams.value = shuffled
  teamAnswers.value = shuffled.map((team) => answersByTeam.get(team.key) ?? null)
  goToCard(0)
}

function restartRound() {
  teamAnswers.value = Array.from({ length: sessionTeamCount.value }, () => null)
  roundComplete.value = false
  goToCard(0)
}

function handleKeydown(event: KeyboardEvent) {
  if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
  const target = event.target
  if (target instanceof HTMLElement && (target.isContentEditable || ['INPUT', 'SELECT', 'TEXTAREA'].includes(target.tagName))) return
  if (!currentTeam.value || roundComplete.value) return

  if (event.code === 'Space') {
    event.preventDefault()
    revealed.value = !revealed.value
  } else if (event.key === 'ArrowLeft') {
    event.preventDefault()
    answerCard(false)
  } else if (event.key === 'ArrowRight') {
    event.preventDefault()
    answerCard(true)
  }
}

watch(currentTeam, (team) => {
  logoFailed.value = false
  robotImage.value = ''
  robotLoading.value = Boolean(team)
  revealed.value = false
  if (team) void loadRobotImage(team)
})

function onRobotImageError() {
  robotImage.value = ''
  robotLoading.value = false
  if (currentTeam.value) robotImageCache.set(currentTeam.value.key, '')
}

onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
  void loadSources()
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
  <div class="app-shell">
    <main class="app-main">
      <div class="study-shell">
        <section class="study-controls" aria-label="Choose a practice set">
          <label class="select-field source-field">
            <select v-model="selectedSet" :disabled="loadingSources">
              <option value="">Choose a region or event</option>
              <optgroup label="Regions">
                <option v-for="district in districts" :key="district.key" :value="`region:${district.key}`">
                  {{ district.display_name }}
                </option>
              </optgroup>
              <optgroup label="Events">
                <option v-for="event in events" :key="event.key" :value="`event:${event.key}`">
                  {{ event.name }}<template v-if="event.city"> · {{ event.city }}</template>
                </option>
              </optgroup>
            </select>
          </label>
          <span class="season-label">{{ season }} SEASON</span>
          <button class="shuffle-button" type="button" aria-label="Shuffle teams" title="Shuffle teams" :disabled="teams.length < 2" @click="shuffleTeams">
            <span aria-hidden="true">⤨</span>
          </button>
        </section>

        <div v-if="loadingSources || loadingTeams" class="state-message" role="status">
          <span class="loading-mark" aria-hidden="true"></span>
          <span>{{ loadingSources ? 'Loading this season’s events…' : 'Loading teams…' }}</span>
        </div>

        <div v-else-if="pageMessage" class="state-message error-message" role="alert">
          <span>{{ pageMessage }}</span>
          <button type="button" class="text-button" @click="loadSources">Try again</button>
        </div>

        <div v-else-if="!selectedDistrictKey && !selectedEventKey" class="state-message empty-message">
          <p>Choose a region or event to start practicing.</p>
        </div>

        <div v-else-if="!teams.length" class="state-message empty-message">
          <p>No teams were found for this selection.</p>
        </div>

        <template v-else-if="currentTeam">
          <button
            :key="`${currentTeam.key}-${cardInstance}`"
            class="flashcard"
            type="button"
            :aria-label="revealed ? `Hide answer for team ${currentTeam.team_number}` : `Reveal answer for team ${currentTeam.team_number}`"
            @click="revealed = !revealed"
          >
            <span class="flashcard-inner" :class="{ 'is-revealed': revealed }">
              <span class="card-face card-front" :aria-hidden="revealed">
                <span class="robot-side">
                  <img
                    v-if="robotImage"
                    class="robot-photo"
                    :src="robotImage"
                    :alt="`${season} robot for team ${currentTeam.team_number}`"
                    @error="onRobotImageError"
                  />
                  <span v-else-if="robotLoading" class="robot-photo-status" role="status">
                    Loading robot photo…
                  </span>
                  <img
                    v-else
                    class="robot-placeholder-icon"
                    src="/robot-placeholder.svg"
                    alt=""
                    aria-hidden="true"
                  />
                </span>
                <span class="team-side number-side">
                  <span class="team-number">{{ currentTeam.team_number }}</span>
                </span>
              </span>
              <span class="card-face card-back" :aria-hidden="!revealed">
                <span class="team-side answer-side">
                  <span class="team-name">{{ currentTeam.nickname || currentTeam.name || `Team ${currentTeam.team_number}` }}</span>
                  <span v-if="teamLocation" class="team-location">{{ teamLocation }}</span>
                  <img
                    v-if="!logoFailed"
                    class="team-logo"
                    :src="teamLogoUrl"
                    :alt="`${currentTeam.nickname || 'Team'} logo`"
                    @error="logoFailed = true"
                  />
                  <span v-else class="team-logo-fallback" aria-hidden="true">{{ teamInitials }}</span>
                </span>
              </span>
            </span>
          </button>

          <section class="deck-summary" aria-label="Practice progress">
            <span>{{ sessionCorrect }} / {{ sessionTeamCount }}</span>
          </section>
          <div
            class="accuracy-progress"
            role="progressbar"
            aria-label="Team answers"
            :aria-valuenow="sessionCorrect"
            :aria-valuetext="`${sessionCorrect} of ${sessionTeamCount} teams answered correctly`"
            aria-valuemin="0"
            :aria-valuemax="Math.max(sessionTeamCount, 1)"
            :style="{ gridTemplateColumns: `repeat(${Math.max(sessionTeamCount, 1)}, minmax(0, 1fr))` }"
          >
            <span
              v-for="(team, index) in teams"
              :key="team.key"
              class="accuracy-segment"
              :class="{
                'is-correct': teamAnswers[index] === true,
                'is-incorrect': teamAnswers[index] === false,
              }"
              :aria-label="`Team ${team.team_number}: ${teamAnswers[index] === true ? 'correct' : teamAnswers[index] === false ? 'incorrect' : 'not answered'}`"
            ></span>
          </div>

          <div class="card-footer">
            <div class="answer-actions" aria-label="Record your answer">
              <button
                class="answer-button incorrect"
                type="button"
                :aria-label="`I missed team ${currentTeam.team_number}`"
                @click="answerCard(false)"
              >
                <span aria-hidden="true">×</span>
              </button>
              <button
                class="answer-button correct"
                type="button"
                :aria-label="`I knew team ${currentTeam.team_number}`"
                @click="answerCard(true)"
              >
                <span aria-hidden="true">✓</span>
              </button>
            </div>
          </div>

        </template>

        <div v-if="!currentTeam" class="accuracy-progress is-placeholder" role="progressbar" aria-label="Team answers" aria-valuenow="0" aria-valuetext="No session selected" aria-valuemin="0" aria-valuemax="1"></div>

        <div v-if="roundComplete" class="round-modal-backdrop">
          <section class="round-modal" role="dialog" aria-modal="true" aria-labelledby="round-modal-title">
            <span class="round-complete-mark" aria-hidden="true">✓</span>
            <h2 id="round-modal-title">Round complete</h2>
            <p>You’ve reviewed all {{ sessionTeamCount }} teams.</p>
            <button class="restart-button" type="button" @click="restartRound">Restart Round</button>
          </section>
        </div>
      </div>
    </main>

  </div>
</template>
