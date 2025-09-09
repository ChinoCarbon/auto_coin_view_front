<template>
  <n-layout>
    <n-layout-header style="display: flex; justify-content: center;">
      <h2 style="color: black; padding: 0 16px;">持仓量动态表格 V2</h2>
    </n-layout-header>
    <n-layout-content style="padding: 16px">
      <CoinTable
        ref="coinTableRef"
        @coin-added="onCoinAdded"
      />
    </n-layout-content>
  </n-layout>
</template>

<script setup>
import { ref } from 'vue'
import CoinTable from '../components/CoinTable.vue'

const coinTableRef = ref(null)

// Handle coin added event from CoinTable (optional)
function onCoinAdded(coin) {
  console.log(`币种 ${coin} 已添加`)
}
</script>

<style scoped>
/* Home.vue specific styles */
</style>
