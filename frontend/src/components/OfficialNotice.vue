<script setup lang="ts">
import type { presentOfficialService } from '../lib/officialPresentation';
defineProps<{ service: ReturnType<typeof presentOfficialService> }>();
</script>

<template>
  <!-- Current impact and upcoming maintenance remain visible. Only supporting
       history / the original wording is folded; all fields stay escaped text. -->
  <p v-if="service.short" class="mt-2 break-words text-sm">{{ service.short }}</p>
  <p v-if="service.maintenanceText" class="mt-2 whitespace-pre-line break-words border-l-2 border-amber-400 pl-3 text-sm">{{ service.maintenanceText }}</p>
  <p v-if="service.status === 'unknown' && !service.message" class="mt-2 text-sm text-[#6b7280]">Status unbekannt</p>
  <details v-if="service.history || service.more || service.date" class="mt-2 text-xs text-[#6b7280]">
    <summary class="cursor-pointer">{{ service.more ? 'Mehr & Verlauf' : 'Verlauf' }}</summary>
    <p v-if="service.more || service.date" class="mt-2 whitespace-pre-line break-words">{{ service.notice }}</p>
    <p v-if="!service.more && !service.date" class="mt-2 whitespace-pre-line break-words">{{ service.history }}</p>
    <p v-else class="mt-2 whitespace-pre-line break-words">{{ service.update }}</p>
  </details>
</template>
