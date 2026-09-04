<script setup lang="ts">
import { computed } from 'vue';
import UptimeBar from './UptimeBar.vue';
import { loginUptimeColors } from '../lib/uptimeColors';
import {
  formatUptimePercent,
  historyLastHour,
  uptimeFromPoints,
} from '../lib/uptimeHistory';
import type { HistoryPayload, SummaryPayload } from '../types';

const props = defineProps<{
  history24h: HistoryPayload;
  summary: SummaryPayload;
}>();

const history1h = computed(() => historyLastHour(props.history24h));
const uptime1h = computed(() => uptimeFromPoints(history1h.value.points));
const uptime24h = computed(() => props.summary.windows['24h'].uptime);
</script>

<template>
  <section class="mt-6 border border-[#d0d7de] bg-white">
    <div class="border-b border-[#d0d7de] px-4 py-3">
      <p class="font-medium">Erreichbarkeit Login</p>
      <p class="text-sm text-[#6b7280]">Schulportal Hessen</p>
    </div>

    <div class="border-b border-[#d0d7de] px-4 py-3">
      <div class="mb-2 flex items-baseline justify-between gap-3">
        <p class="text-sm font-medium">Letzte Stunde</p>
        <p class="text-sm tabular-nums text-[#1f8b4c]">
          {{ formatUptimePercent(uptime1h) }}
        </p>
      </div>
      <UptimeBar
        :history="history1h"
        :segments="60"
        :per-point="true"
        :rounded="true"
        :up-color="loginUptimeColors.up"
        :down-color="loginUptimeColors.down"
        :no-data-color="loginUptimeColors.noData"
        test-id="uptime-bar-1h"
      />
    </div>

    <div class="px-4 py-3">
      <div class="mb-2 flex items-baseline justify-between gap-3">
        <p class="text-sm font-medium">Letzte 24 Stunden</p>
        <p class="text-sm tabular-nums text-[#1f8b4c]">
          {{ formatUptimePercent(uptime24h) }}
        </p>
      </div>
      <UptimeBar
        :history="history24h"
        :segments="48"
        :rounded="true"
        :up-color="loginUptimeColors.up"
        :down-color="loginUptimeColors.down"
        :no-data-color="loginUptimeColors.noData"
        test-id="uptime-bar-24h"
      />
    </div>
  </section>
</template>
