<template>
  <n-layout>
    <n-layout-header class="header-container">
      <div class="header-content">
        <h6 class="header-title">动态表格 V4.0</h6>
        
      <!-- 操作按钮组 -->
      <div class="header-actions">
        
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
      </div>
    </n-layout-header>
    
     <n-layout-content style="padding: 16px">
      <!-- 管理员模式：显示两个tab -->
      <div v-if="isAdminMode">
        <n-tabs type="line" animated>
          <!-- 管理员表格 Tab -->
          <n-tab-pane name="admin-table" tab="管理员表格">
            <div class="tab-content">
              <h3 style="color: #1890ff; margin-bottom: 16px;">管理员面板</h3>
              <CoinTable 
                ref="adminTableRef"
                api-prefix="/admin"
                @coin-added="onAdminCoinAdded"
                @notification-added="onNotificationAdded"
              />
            </div>
          </n-tab-pane>

          <!-- 用户管理 Tab -->
          <n-tab-pane name="user-management" tab="用户管理">
            <div class="tab-content">
              <h3 style="color: #1890ff; margin-bottom: 16px;">用户管理</h3>
              <UserManagement />
            </div>
          </n-tab-pane>
        </n-tabs>
      </div>

      <!-- 普通用户模式：只显示表格 -->
      <div>
        <CoinTable 
          ref="coinTableRef"
          api-prefix=""
          @coin-added="onCoinAdded"
          @notification-added="onNotificationAdded"
        />
      </div>
    </n-layout-content>
    
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
  </n-layout>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { NButton, NIcon, NBadge, NDrawer, NDrawerContent, NEmpty, NTabs, NTabPane } from 'naive-ui'
import CoinTable from '../components/CoinTable.vue'
import UserManagement from '../components/UserManagement.vue'

const coinTableRef = ref(null)
const adminTableRef = ref(null)
const isAdminMode = ref(false)

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
/* Home.vue specific styles */
.header-container {
  padding: 0 16px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

.header-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  max-width: 1200px;
  position: relative;
}

.header-title {
  color: var(--n-text-color);
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
}

.header-actions {
  position: absolute;
  right: 16px;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  gap: 12px;
  z-index: 10;
}

.notification-icon {
  cursor: pointer;
  transition: transform 0.2s;
}

.notification-icon:hover {
  transform: scale(1.1);
}

/* Tab content styles */
.tab-content {
  padding: 16px 0;
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
