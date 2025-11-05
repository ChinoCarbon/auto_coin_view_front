<template>
  <n-layout>
    
     <n-layout-content style="padding: 0px; padding-bottom: 60px;">
      <!-- 管理员面板区域 -->
      <div>
        <!-- 完整管理员：显示Tab导航 -->
        <div v-if="showUserManagement" class="custom-tabs">
          <div class="tab-nav">
            <div 
              class="tab-nav-item" 
              :class="{ 'active': activeTab === 'admin-table' }"
              @click="switchTab('admin-table')"
            >
              管理员表格
            </div>
            <div 
              class="tab-nav-item" 
              :class="{ 'active': activeTab === 'user-management' }"
              @click="switchTab('user-management')"
            >
              用户管理
            </div>
          </div>
          
          <!-- Tab内容区域 -->
          <div class="tab-content-wrapper">
            <!-- 管理员表格 Tab -->
            <div v-show="activeTab === 'admin-table'" class="tab-content">
              <h3 v-if="showUserManagement" style="color: #1890ff; margin-bottom: 5px;">
                管理员面板
              </h3>
              <CoinTable 
                ref="adminTableRef"
                api-prefix="/admin"
                :current-user="currentUser"
                @coin-added="onAdminCoinAdded"
                @notification-added="onNotificationAdded"
              />
            </div>

            <!-- 用户管理 Tab -->
            <div v-show="activeTab === 'user-management'" class="tab-content">
              <h3 style="color: #1890ff; margin-bottom: 5px;">用户管理</h3>
              <UserManagement />
            </div>
          </div>
        </div>
        
        <!-- 普通用户或无参数：直接显示管理员表格，不显示Tab -->
        <div v-else>
          <h3 style="color: #1890ff; margin-bottom: 5px;">用户分面板</h3>
          <CoinTable 
            ref="adminTableRef"
            api-prefix="/admin"
            :current-user="currentUser"
            @coin-added="onAdminCoinAdded"
            @notification-added="onNotificationAdded"
          />
        </div>
      </div>

      <hr style="margin: 20px; color: #333333;">

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

    <n-layout-footer class="footer-container">
      <div class="footer-content">
        <span class="footer-title">动态表格 V8.1</span>
      </div>
    </n-layout-footer>
    
    <!-- 通知抽屉已移动到App.vue -->
  </n-layout>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import CoinTable from '../components/CoinTable.vue'
import UserManagement from '../components/UserManagement.vue'

// 定义emit
const emit = defineEmits(['notification-added'])

const coinTableRef = ref(null)
const adminTableRef = ref(null)
const showUserManagement = ref(false) // 是否显示用户管理Tab (admin=true 时为 true)
const currentUser = ref('') // 当前用户名（user=xxx 时有值，admin=true 时为空）
const activeTab = ref('admin-table') // 默认激活管理员表格tab

// 检查URL参数来确定权限模式
onMounted(() => {
  const urlParams = new URLSearchParams(window.location.search)
  const adminParam = urlParams.get('admin')
  const userParam = urlParams.get('user')
  
  if (adminParam === 'true') {
    // admin=true: 完整管理员模式
    showUserManagement.value = true
    currentUser.value = ''
    localStorage.setItem('currentUser', '')
  } else if (userParam) {
    // user=xxx: 普通用户模式
    showUserManagement.value = false
    currentUser.value = userParam
    localStorage.setItem('currentUser', userParam)
  } else {
    // 无参数：从 localStorage 恢复
    const storedUser = localStorage.getItem('currentUser')
    if (storedUser !== null) {
      // 有存储的权限信息
      currentUser.value = storedUser
      showUserManagement.value = !storedUser // 空字符串表示管理员
    } else {
      // 无参数且无存储：第一次访问，默认为普通用户模式
      showUserManagement.value = false
      currentUser.value = 'guest' // 设置一个默认用户名
      localStorage.setItem('currentUser', 'guest')
    }
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

// 处理通知添加事件 - 转发到App.vue
function onNotificationAdded(notification) {
  // 通过emit将事件传递给父组件App.vue
  emit('notification-added', notification)
}

// Tab切换函数
function switchTab(tabName) {
  activeTab.value = tabName
  console.log(`切换到Tab: ${tabName}`)
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

/* 通知图标样式已移动到App.vue */

/* 自定义Tab样式 - 简单美化 */
.custom-tabs {
  width: 100%;
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  margin-bottom: 16px;
  border: 1px solid #e8e8e8;
}

.tab-nav {
  display: flex;
  background: #f8f9fa;
  margin-bottom: 0;
  border-radius: 8px 8px 0 0;
}

.tab-nav-item {
  padding: 12px 24px;
  cursor: pointer;
  transition: all 0.3s ease;
  font-size: 14px;
  font-weight: 500;
  color: #666;
  position: relative;
  user-select: none;
  flex: 1;
  text-align: center;
  border-bottom: 2px solid transparent;
}

.tab-nav-item:hover {
  color: #1890ff;
  background: #f0f8ff;
}

.tab-nav-item.active {
  color: #1890ff;
  background: #fff;
  border-bottom-color: #1890ff;
}

.tab-content-wrapper {
  background: #fff;
  border-radius: 0 0 8px 8px;
}

/* Tab content styles - 保持原样 */
.tab-content {
  padding: 5px 0;
}

/* Footer样式 */
.footer-container {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--n-card-color);
  border-top: 1px solid var(--n-border-color);
  padding: 8px 16px;
  z-index: 100;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
}

.footer-content {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.footer-title {
  color: var(--n-text-color-2);
  font-size: 12px;
  font-weight: 400;
  margin: 0;
}

/* 通知抽屉样式已移动到App.vue */
</style>
