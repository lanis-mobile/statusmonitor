<script setup lang="ts">
import { computed, defineAsyncComponent, ref } from 'vue';
import RangePills from './components/RangePills.vue';
import LoginAvailability from './components/LoginAvailability.vue';
import IncidentList from './components/IncidentList.vue';
import OfficialStatus from './components/OfficialStatus.vue';
import { windowForIncident } from './lib/chartData';
import { bannerTitle, formatCheckedAt } from './lib/statusCopy';
import { windowsWithAdditionalData } from './lib/windows';
import type {
  HistoryPayload,
  HistoryWindow,
  HolidayPeriod,
  SummaryPayload,
} from './types';

const StatusChart = defineAsyncComponent(() => import('./components/StatusChart.vue'));

const props = defineProps<{
  summary: SummaryPayload | null;
  history: HistoryPayload | null;
  history24h: HistoryPayload | null;
  history30d: HistoryPayload | null;
  incidents: Array<{ start: number; end: number }>;
  holidays: HolidayPeriod[];
  range: HistoryWindow;
  windows: HistoryWindow[];
  labels: Record<HistoryWindow, string>;
  load: (window: HistoryWindow) => void;
  loading: boolean;
  error: string | null;
}>();

const tab = ref<'official' | 'incidents' | 'latency' | 'uptime'>('official');
const excludeHolidays = ref(true);
const availabilityWindows = computed(() =>
  excludeHolidays.value ? props.summary?.windowsExcludingHolidays : props.summary?.windows,
);
const chartHighlight = ref<{ start: number; end: number } | null>(null);
const chartWindows = computed(() =>
  props.summary ? windowsWithAdditionalData(props.windows, props.summary) : [],
);

const chartTheme = {
  line: '#2563eb',
  area: 'rgba(37, 99, 235, 0.08)',
  holiday: 'rgba(234, 179, 8, 0.22)',
  down: 'rgba(192, 57, 43, 0.32)',
  noData: 'rgba(156, 163, 175, 0.28)',
  axis: '#6b7280',
  grid: '#e5e7eb',
  tooltipBg: '#111827',
  tooltipText: '#f9fafb',
  up: '#1f8b4c',
};

function focusIncident(range: { start: number; end: number }) {
  if (!props.summary || !props.history24h) return;
  const now = props.summary.current.checkedAt ?? props.history24h.to;
  void props.load(windowForIncident(range.start, now));
  tab.value = 'latency';
  chartHighlight.value = range;
}
</script>

<template>
  <div class="min-h-dvh bg-[#f4f5f7] text-[#1f2328]" style="font-family: system-ui, sans-serif">
    <div
      v-if="summary"
      class="px-4 py-3 text-sm text-white sm:px-8"
      :class="
        summary.current.status === 'operational'
          ? 'bg-[#1f8b4c]'
          : summary.current.status === 'misconfigured'
            ? 'bg-[#b45309]'
            : 'bg-[#c0392b]'
      "
      data-testid="status-banner"
    >
      <div class="mx-auto flex max-w-5xl flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
        <strong class="text-base">{{ bannerTitle[summary.current.status] }}</strong>
        <span>
          Letzter Check {{ formatCheckedAt(summary.current.checkedAt) }}
          ·
          {{ summary.current.responseMs != null ? `${summary.current.responseMs} ms` : 'kein Wert' }}
        </span>
      </div>
    </div>

    <div class="mx-auto max-w-5xl px-4 py-6 sm:px-8">
      <p class="text-xs tracking-wide text-[#6b7280] uppercase">Lanis-Mobile</p>
      <h1 class="mt-1 text-2xl font-semibold">Schulportal Hessen</h1>
      <p v-if="summary?.current.inHolidays" class="mt-1 text-sm text-[#6b7280]" data-testid="holiday-hint">
        Derzeit Schulferien ({{ summary.current.holidayLabel }}).
      </p>

      <LoginAvailability v-if="history24h && summary" :history24h="history24h" :history30d="history30d" :summary="summary" />

      <section class="mt-4 border border-[#d0d7de] bg-white">
        <div
          class="flex overflow-x-auto overflow-y-hidden border-b border-[#d0d7de]"
          role="tablist"
          aria-label="Details"
        >
          <button
            type="button"
            role="tab"
            data-testid="tab-official"
            class="shrink-0 border-b-2 px-4 py-3 text-sm"
            :class="tab === 'official' ? 'border-[#1f2328] font-medium' : 'border-transparent text-[#6b7280]'"
            :aria-selected="tab === 'official'"
            @click="tab = 'official'"
          >
            Offizielle Meldungen
          </button>
          <button
            type="button"
            role="tab"
            data-testid="tab-incidents"
            class="shrink-0 border-b-2 px-4 py-3 text-sm"
            :class="
              tab === 'incidents'
                ? 'border-[#1f2328] font-medium'
                : 'border-transparent text-[#6b7280]'
            "
            :aria-selected="tab === 'incidents'"
            @click="tab = 'incidents'"
          >
            Vergangene Störungen
          </button>
          <button
            type="button"
            role="tab"
            data-testid="tab-latency"
            class="shrink-0 border-b-2 px-4 py-3 text-sm"
            :class="
              tab === 'latency'
                ? 'border-[#1f2328] font-medium'
                : 'border-transparent text-[#6b7280]'
            "
            :aria-selected="tab === 'latency'"
            @click="tab = 'latency'"
          >
            Antwortzeit
          </button>
          <button
            type="button"
            role="tab"
            data-testid="tab-uptime"
            class="shrink-0 border-b-2 px-4 py-3 text-sm"
            :class="
              tab === 'uptime'
                ? 'border-[#1f2328] font-medium'
                : 'border-transparent text-[#6b7280]'
            "
            :aria-selected="tab === 'uptime'"
            @click="tab = 'uptime'"
          >
            Verfügbarkeit
          </button>
        </div>

        <OfficialStatus v-show="tab === 'official'" />
        <p v-if="tab !== 'official' && loading" class="p-4 text-sm text-[#6b7280]">Lade Status…</p>
        <p v-else-if="tab !== 'official' && error" class="p-4 text-sm text-red-800">{{ error }}</p>
        <div v-else-if="tab === 'incidents' && summary && history24h">
          <IncidentList
            :incidents="incidents"
            :status="summary.current.status"
            :now="summary.current.checkedAt ?? history24h.to"
            @select="focusIncident"
          />
        </div>

        <div v-else-if="tab === 'latency' && history">
          <div class="flex flex-wrap gap-1.5 border-b border-[#d0d7de] px-4 py-3 sm:justify-end">
            <RangePills
              :windows="chartWindows"
              :labels="labels"
              :range="range"
              button-class="border border-[#d0d7de] bg-white px-2 py-1 text-xs text-[#6b7280]"
              active-class="!border-[#1f2328] !text-[#1f2328]"
              @select="load"
            />
          </div>
          <div class="px-2 py-2 sm:px-4">
            <Suspense>
              <StatusChart
                :history="history"
                :holidays="holidays"
                :theme="chartTheme"
                :highlight-range="chartHighlight"
                @incident-select="focusIncident"
              />
              <template #fallback>
                <p class="chart-loading">Chart wird geladen…</p>
              </template>
            </Suspense>
          </div>
          <p class="border-t border-[#d0d7de] px-4 py-2 text-xs text-[#6b7280]" data-testid="holiday-legend">
            Grau: Keine Daten · Gelb: Schulferien Hessen · Rot: Nicht erreichbar
          </p>
        </div>

        <div
          v-else-if="tab === 'uptime' && summary"
          data-testid="uptime-stats"
        >
          <div class="flex flex-wrap items-center justify-end gap-3 border-b border-[#d0d7de] px-4 py-3">
            <button
              type="button"
              role="switch"
              :aria-checked="excludeHolidays"
              class="flex items-center gap-2 text-sm focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[#2563eb]"
              @click="excludeHolidays = !excludeHolidays"
            >
              Schulferien ausschließen
              <span
                aria-hidden="true"
                class="inline-flex h-5 w-9 shrink-0 items-center rounded-full p-0.5 transition-colors"
                :class="excludeHolidays ? 'bg-[#1f8b4c]' : 'bg-[#9ca3af]'"
              >
                <span class="h-4 w-4 rounded-full bg-white transition-transform" :class="excludeHolidays ? 'translate-x-4' : 'translate-x-0'" />
              </span>
            </button>
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7">
            <div
              v-for="id in chartWindows"
              :key="id"
              class="-mb-px -mr-px border border-[#d0d7de] bg-white px-3 py-3"
            >
              <p class="text-xs text-[#6b7280]">{{ labels[id] }}</p>
              <p class="mt-1 text-lg tabular-nums">
                {{ availabilityWindows?.[id]?.checks ? `${availabilityWindows[id].uptime.toFixed(2)}%` : 'Keine Daten' }}
              </p>
            </div>
          </div>
        </div>
      </section>

      <p class="mt-6 text-center text-xs text-[#c5cad1]">
        Schulferiendaten von
        <a
          href="https://schulferien-api.de"
          class="text-[#c5cad1] underline decoration-[#d8dce1] underline-offset-2 hover:text-[#9aa3ad]"
          target="_blank"
          rel="noopener noreferrer"
        >schulferien-api.de</a>
        ·
        <a
          href="https://github.com/lanis-mobile/statusmonitor"
          class="text-[#c5cad1] underline decoration-[#d8dce1] underline-offset-2 hover:text-[#9aa3ad]"
          target="_blank"
          rel="noopener noreferrer"
        >lanis-mobile/statusmonitor</a>
      </p>
    </div>
  </div>
</template>

<style scoped>
.chart-loading {
  display: flex;
  height: 240px;
  align-items: center;
  justify-content: center;
  margin: 0;
  font-size: 0.875rem;
  color: #6b7280;
}

@media (min-width: 640px) {
  .chart-loading {
    height: 320px;
  }
}
</style>
