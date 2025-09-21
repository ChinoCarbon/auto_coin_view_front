<template>
  <n-config-provider>
    <n-notification-provider>
      <n-layout style="height: 100vh">
      <n-layout-header class="app-header">
        <div class="header-content">
          <!-- Logo区域 -->
          <div class="logo-section">
            <div class="logo-icon">
              <svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
              </svg>
            </div>
            <span class="logo-text">动态表格</span>
          </div>
          
          <!-- 菜单区域 -->
          <div class="menu-section">
            <n-menu :options="menuOptions" mode="horizontal" @update:value="onMenuClick" />
          </div>
          
          <!-- 通知图标 -->
          <div class="notification-icon" @click="showNotificationDrawer = true">
            <n-badge :value="notificationCount" :max="99">
              <n-button quaternary circle>
                <template #icon>
                  <n-icon size="20">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/>
                    </svg>
                  </n-icon>
                </template>
              </n-button>
            </n-badge>
          </div>
        </div>
      </n-layout-header>
      <n-layout-content style="padding: 16px">
        <!-- 关键：路由出口 -->
        <router-view @notification-added="onNotificationAdded" />
      </n-layout-content>
    </n-layout>
    
    <!-- 通知抽屉 -->
    <n-drawer
      v-model:show="showNotificationDrawer"
      :width="400"
      placement="right"
      :mask-closable="true"
    >
      <n-drawer-content title="通知中心" closable class="drawer-content">
        <!-- 通知列表区域 -->
        <div class="notification-list">
          <div v-if="notifications.length === 0" class="empty-state">
            <n-empty description="暂无通知" />
          </div>
          
          <div v-else>
            <div 
              v-for="notification in notifications" 
              :key="notification.id"
              class="notification-item"
              :class="{ 'is-unread': !notification.read }"
            >
              <div class="notification-header">
                <span class="notification-type">{{ notification.type }}</span>
                <span class="notification-time">{{ notification.time }}</span>
              </div>
              <div class="notification-content">
                <strong>{{ notification.coin }}</strong> 在 {{ notification.timestamp }}
              </div>
              <div class="notification-details">
                {{ notification.type }}为{{ notification.formattedActual }}，超过阈值{{ notification.formattedThreshold }}
              </div>
              <div class="notification-actions">
                <n-button 
                  size="tiny" 
                  type="error" 
                  @click="removeNotification(notification.id)"
                >
                  删除
                </n-button>
                <n-button 
                  size="tiny" 
                  @click="markAsRead(notification.id)"
                  v-if="!notification.read"
                >
                  标记已读
                </n-button>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 底部操作按钮 - 固定在底部 -->
        <div class="drawer-footer" v-if="notifications.length > 0">
          <div class="drawer-actions">
            <n-button 
              type="primary" 
              size="medium" 
              @click="markAllAsRead"
              :disabled="unreadCount === 0"
            >
              全部已读
            </n-button>
            <n-button 
              type="error" 
              size="medium" 
              @click="clearAllNotifications"
              :disabled="notifications.length === 0"
            >
              清空全部
            </n-button>
          </div>
        </div>
      </n-drawer-content>
    </n-drawer>
    </n-notification-provider>
  </n-config-provider>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { NConfigProvider, NLayout, NLayoutHeader, NLayoutContent, NMenu, NNotificationProvider, NButton, NIcon, NBadge, NDrawer, NDrawerContent, NEmpty } from 'naive-ui'

const router = useRouter()

const menuOptions = [
  { label: '首页', key: '/' },
]

// 通知相关状态
const showNotificationDrawer = ref(false)
const notifications = ref([])

// 计算未读通知数量
const notificationCount = computed(() => {
  return notifications.value.filter(n => !n.read).length
})

// 计算未读数量（用于按钮禁用状态）
const unreadCount = computed(() => {
  return notifications.value.filter(n => !n.read).length
})

function onMenuClick(key) {
  router.push(key)
}

// 处理通知添加事件
function onNotificationAdded(notification) {
  notifications.value.unshift({
    ...notification,
    read: false
  })
}

// 删除单个通知
function removeNotification(id) {
  const index = notifications.value.findIndex(n => n.id === id)
  if (index > -1) {
    notifications.value.splice(index, 1)
  }
}

// 标记通知为已读
function markAsRead(id) {
  const notification = notifications.value.find(n => n.id === id)
  if (notification) {
    notification.read = true
  }
}

// 清空所有通知
function clearAllNotifications() {
  notifications.value = []
}

// 标记所有通知为已读
function markAllAsRead() {
  notifications.value.forEach(notification => {
    notification.read = true
  })
}
</script>

<style scoped>
/* App.vue specific styles */
.app-header {
  padding: 0 24px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
}

.header-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  max-width: 1400px;
  position: relative;
}

/* Logo区域样式 */
.logo-section {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  transition: all 0.3s ease;
  padding: 8px 12px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.logo-section:hover {
  background: rgba(255, 255, 255, 0.15);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.logo-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 8px;
  color: white;
  transition: all 0.3s ease;
}

.logo-section:hover .logo-icon {
  background: rgba(255, 255, 255, 0.3);
  transform: rotate(5deg);
}

.logo-text {
  color: white;
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.5px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* 菜单区域样式 */
.menu-section {
  flex: 1;
  display: flex;
  justify-content: center;
  margin: 0 40px;
}

.notification-icon {
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  z-index: 10;
}

.notification-icon:hover {
  transform: scale(1.15);
  filter: drop-shadow(0 4px 12px rgba(0, 0, 0, 0.2));
}

.notification-icon :deep(.n-button) {
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.2);
  color: white;
  backdrop-filter: blur(10px);
  transition: all 0.3s ease;
}

.notification-icon :deep(.n-button:hover) {
  background: rgba(255, 255, 255, 0.25);
  border-color: rgba(255, 255, 255, 0.4);
  transform: scale(1.05);
}

.notification-icon :deep(.n-badge .n-badge-sup) {
  background: #ff4757;
  color: white;
  font-weight: 600;
  font-size: 11px;
  min-width: 18px;
  height: 18px;
  border-radius: 9px;
  box-shadow: 0 2px 8px rgba(255, 71, 87, 0.4);
}

/* 菜单样式美化 */
.header-content :deep(.n-menu) {
  background: transparent;
  border: none;
  font-weight: 500;
}

.header-content :deep(.n-menu .n-menu-item) {
  color: rgba(255, 255, 255, 0.8);
  background: transparent;
  border-radius: 8px;
  margin: 0 4px;
  padding: 8px 16px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
}

.header-content :deep(.n-menu .n-menu-item::before) {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.1);
  opacity: 0;
  transition: opacity 0.3s ease;
  border-radius: 8px;
}

.header-content :deep(.n-menu .n-menu-item:hover) {
  color: white;
  background: rgba(255, 255, 255, 0.15);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.header-content :deep(.n-menu .n-menu-item:hover::before) {
  opacity: 1;
}

.header-content :deep(.n-menu .n-menu-item.n-menu-item--selected) {
  color: white;
  background: rgba(255, 255, 255, 0.2);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.header-content :deep(.n-menu .n-menu-item.n-menu-item--selected::after) {
  content: '';
  position: absolute;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 20px;
  height: 2px;
  background: white;
  border-radius: 1px;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .app-header {
    padding: 0 16px;
    height: 56px;
  }
  
  .header-content {
    max-width: 100%;
  }
  
  .logo-section {
    padding: 6px 8px;
    gap: 8px;
  }
  
  .logo-text {
    font-size: 16px;
  }
  
  .logo-icon {
    width: 28px;
    height: 28px;
  }
  
  .menu-section {
    margin: 0 20px;
  }
  
  .header-content :deep(.n-menu .n-menu-item) {
    padding: 6px 12px;
    margin: 0 2px;
    font-size: 14px;
  }
}

/* 添加一些动画效果 */
@keyframes fadeInDown {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.app-header {
  animation: fadeInDown 0.6s ease-out;
}

.logo-section {
  animation: fadeInDown 0.8s ease-out;
}

.menu-section {
  animation: fadeInDown 1s ease-out;
}

.notification-icon {
  animation: fadeInDown 1.2s ease-out;
}

.drawer-content {
  position: relative;
  height: calc(100vh - 60px);
  max-height: calc(100vh - 60px);
  display: flex;
  flex-direction: column;
}

.notification-list {
  flex: 1;
  overflow-y: auto;
  padding: 0 16px 16px 16px;
  margin-bottom: 80px; /* 为底部按钮留出空间 */
}

.notification-item {
  padding: 12px;
  border: 1px solid var(--n-border-color);
  border-radius: 8px;
  margin-bottom: 8px;
  background: var(--n-card-color);
  transition: all 0.2s;
}

.notification-item.is-unread {
  border-left: 4px solid #ff4d4f;
  background: var(--n-card-color);
}

.notification-item:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.notification-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.notification-type {
  font-weight: bold;
  color: #ff4d4f;
  font-size: 12px;
  padding: 2px 6px;
  background: #fff2f0;
  border-radius: 4px;
}

.notification-time {
  font-size: 12px;
  color: var(--n-text-color-disabled);
}

.notification-content {
  font-size: 14px;
  margin-bottom: 4px;
  color: var(--n-text-color);
}

.notification-details {
  font-size: 12px;
  color: var(--n-text-color-secondary);
  margin-bottom: 8px;
}

.notification-actions {
  display: flex;
  gap: 8px;
}

.empty-state {
  text-align: center;
  padding: 40px 0;
}

.drawer-actions {
  display: flex;
  gap: 8px;
}

.drawer-footer {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  padding: 16px;
  border-top: 1px solid var(--n-border-color);
  z-index: 10;
  width: 100%;
}

.drawer-footer .drawer-actions {
  display: flex;
  flex-direction: row;
  gap: 12px;
  justify-content: center;
  align-items: center;
}
</style>

