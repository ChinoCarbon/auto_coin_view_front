<template>
  <n-notification-provider>
    <n-layout style="height: 100vh">
      <n-layout-header>
        <n-menu :options="menuOptions" mode="horizontal" @update:value="onMenuClick" />
      </n-layout-header>
      <n-layout-content style="padding: 16px">
        <!-- 关键：路由出口 -->
        <router-view />
      </n-layout-content>
    </n-layout>
  </n-notification-provider>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { NLayout, NLayoutHeader, NLayoutContent, NMenu, NNotificationProvider } from 'naive-ui'

const router = useRouter()

const menuOptions = [
  { label: '首页', key: '/' },
]

function onMenuClick(key) {
  router.push(key)
}
</script>

