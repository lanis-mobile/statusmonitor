<script setup lang="ts">
import type { OfficialService } from '../lib/officialPresentation';
defineProps<{ service: OfficialService }>();
const statusLabels = {
  operational: 'Keine Einschränkungen bekannt',
  restricted: 'Eingeschränkt oder nicht verfügbar',
  unknown: 'Status unbekannt',
};
</script>

<template>
  <h2 class="flex items-start gap-2 text-base font-semibold">
    <span class="mt-1 inline-flex shrink-0 items-center gap-1">
      <span
        role="img"
        tabindex="0"
        :title="statusLabels[service.status] ?? statusLabels.unknown"
        :aria-label="statusLabels[service.status] ?? statusLabels.unknown"
        class="inline-flex h-5 w-5 items-center justify-center rounded-full border-2 text-xs leading-none"
        :class="service.status === 'operational' ? 'text-green-800' : service.status === 'restricted' ? 'text-red-800' : 'text-neutral-600'"
      >{{ service.status === 'operational' ? '✓' : service.status === 'restricted' ? '!' : '?' }}</span>
      <span
        v-if="service.maintenance"
        role="img"
        tabindex="0"
        title="Wartung oder Ausfall angekündigt"
        aria-label="Wartung oder Ausfall angekündigt"
        class="inline-flex h-5 w-5 items-center justify-center text-base leading-none text-amber-800"
      >🛠</span>
    </span>
    <span class="min-w-0 break-words">{{ service.name }}</span>
  </h2>
</template>
