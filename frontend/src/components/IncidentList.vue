<script setup lang="ts">
import { computed } from 'vue';
import { buildIncidents } from '../lib/incidents';
import { formatCheckedAt, formatDuration, statusTitle } from '../lib/statusCopy';
import type { HistoryPayload, MonitorStatus } from '../types';

const props = defineProps<{
  recent: HistoryPayload;
  longer: HistoryPayload;
  status: MonitorStatus;
  now: number;
}>();

const emit = defineEmits<{
  select: [range: { start: number; end: number }];
}>();

const incidents = computed(() =>
  buildIncidents(props.recent, props.longer, props.status, props.now),
);
</script>

<template>
  <div data-testid="incident-list">
    <p v-if="incidents.length === 0" class="px-4 py-6 text-sm text-[#6b7280]">
      Keine Störungen in den letzten 30 Tagen.
    </p>
    <ol v-else class="divide-y divide-[#d0d7de]">
      <li
        v-for="item in incidents"
        :key="`${item.start}-${item.end}`"
        class="flex gap-3 px-4 py-3"
        :data-ongoing="item.ongoing ? 'true' : 'false'"
      >
        <button
          type="button"
          class="flex w-full gap-3 text-left"
          @click="emit('select', { start: item.start, end: item.end })"
        >
          <span
            class="mt-1.5 h-2 w-2 shrink-0"
            :class="item.ongoing ? 'bg-[#c0392b]' : 'bg-[#9aa3ad]'"
          ></span>
          <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
            <p class="font-medium">{{ statusTitle.down }}</p>
            <p class="text-sm tabular-nums text-[#6b7280]">
              <template v-if="item.ongoing">
                läuft seit {{ formatDuration(now - item.start) }}
              </template>
              <template v-else>
                {{ formatDuration(item.end - item.start) }}
              </template>
            </p>
          </div>
          <p class="mt-0.5 text-sm text-[#6b7280]">
            <template v-if="item.ongoing">
              Seit {{ formatCheckedAt(item.start) }}
            </template>
            <template v-else>
              {{ formatCheckedAt(item.start) }}
              –
              {{ formatCheckedAt(item.end) }}
            </template>
          </p>
          <p
            class="mt-1 text-xs"
            :class="item.ongoing ? 'text-[#c0392b]' : 'text-[#6b7280]'"
          >
            {{ item.ongoing ? 'Andauernd' : 'Behoben' }}
          </p>
          </div>
        </button>
      </li>
    </ol>
  </div>
</template>
