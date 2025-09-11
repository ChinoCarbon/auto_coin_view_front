<template>
  <n-layout>
    <n-layout-header style="display: flex; justify-content: center;">
      <h2 style="color: black; padding: 0 16px;">动态表格 V2.1</h2>
    </n-layout-header>
    <n-layout-content style="padding: 16px">
      <!-- 普通用户表格 -->
      <div>
        <CoinTable
          ref="coinTableRef"
          api-prefix=""
          @coin-added="onCoinAdded"
        />
      </div>
      
      <!-- 管理员表格 -->
      <div v-if="isAdminMode" style="margin-top: 32px;">
        <h3 style="color: #1890ff; margin-bottom: 16px;">管理员面板</h3>
        <CoinTable
          ref="adminTableRef"
          api-prefix="/admin"
          @coin-added="onAdminCoinAdded"
        />
      </div>
    </n-layout-content>
  </n-layout>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import CoinTable from '../components/CoinTable.vue'

const coinTableRef = ref(null)
const adminTableRef = ref(null)
const isAdminMode = ref(false)

// 检查URL参数或localStorage来确定是否为管理员模式
onMounted(() => {
  const urlParams = new URLSearchParams(window.location.search)
  const adminParam = urlParams.get('admin')
  
  if (adminParam === 'true') {
    isAdminMode.value = true
    localStorage.setItem('isAdmin', 'true')
  } else {
    const storedAdmin = localStorage.getItem('isAdmin')
    isAdminMode.value = storedAdmin === 'true'
  }
})

// Handle coin added event from regular table
function onCoinAdded(coin) {
  console.log(`普通用户：币种 ${coin} 已添加`)
}

// Handle coin added event from admin table
function onAdminCoinAdded(coin) {
  console.log(`管理员：币种 ${coin} 已添加`)
}
</script>

<style scoped>
/* Home.vue specific styles */
</style>
