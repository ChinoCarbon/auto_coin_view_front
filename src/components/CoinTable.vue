<template>
  <div>
    <div class="controls-row">
      <n-auto-complete 
        v-model:value="inputValue" 
        :options="autoCompleteOptions" 
        placeholder="请输入币种名称" 
        @keyup.enter="onSearch" 
        style="width: 300px; margin-right: 16px;"
      />
      <n-switch 
        v-model:value="soundEnabled" 
        size="small"
      >
        <template #checked>
          🔊 提示音
        </template>
        <template #unchecked>
          🔇 静音
        </template>
      </n-switch>
      
      <!-- 导出按钮 -->
      <n-button 
        type="primary" 
        size="small" 
        @click="exportSelectedData"
        :disabled="selectedRowKeys.length === 0"
        style="margin-left: 16px;"
      >
        导出选中数据 ({{ selectedRowKeys.length }})
      </n-button>
      
      <!-- 导出今日全部数据按钮 -->
      <n-button 
        type="info" 
        size="small" 
        @click="exportTodayAllData"
        style="margin-left: 8px;"
      >
        导出今日全部数据
      </n-button>
    </div>
    
     <!-- 颜色含义说明 -->
     <div class="color-legend">
       <span class="legend-item">
         <span class="color-box" style="background-color: #dcfce7;"></span>
         正常上涨
       </span>
       <span class="legend-item">
         <span class="color-box" style="background-color: #dbeafe;"></span>
         快速拉升(≥2%)
       </span>
       <span class="legend-item">
         <span class="color-box" style="background-color: #fef3c7;"></span>
         下跌
       </span>
       <span class="legend-item">
         <span class="color-box" style="background-color: #fecaca;"></span>
         跌破阈值
       </span>
     </div>
    <div class="table-wrapper" ref="tableWrapperRef">
      <n-data-table 
        ref="dataTableRef" 
        :columns="columns" 
        :data="tableData" 
        :scroll-x="scrollX" 
        size="small" 
        bordered 
        striped
        :default-sort="{ columnKey: 'coin', order: 'descend' }"
        :row-key="row => row.coin"
        v-model:checked-row-keys="selectedRowKeys"
        @update:checked-row-keys="onCheckedRowKeysChange"
        :pagination="false"
      />
    </div>
    
    <!-- 快速下单确认模态框 -->
    <n-modal v-model:show="showQuickOrderConfirmModal" preset="dialog" title="快速下单确认" size="large">
      <div v-if="quickOrderConfirmData.settings">
        <n-descriptions :column="2" bordered>
          <n-descriptions-item label="交易对">
            <n-tag :type="quickOrderConfirmData.side === 'BUY' ? 'success' : 'warning'">
              {{ quickOrderConfirmData.symbol }}
            </n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="交易方向">
            <n-tag :type="quickOrderConfirmData.side === 'BUY' ? 'success' : 'warning'">
              {{ quickOrderConfirmData.side === 'BUY' ? '开多' : '开空' }}
            </n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="杠杆倍数">
            <n-tag type="info">{{ quickOrderConfirmData.settings.leverage }}x</n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="仓位百分比">
            <n-tag type="info">{{ quickOrderConfirmData.settings.positionPercentage }}%</n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="用户模式">
            <n-tag type="primary">
              {{ quickOrderConfirmData.settings.useAllUsers ? '全部用户' : '指定用户' }}
            </n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="订单类型">
            <n-tag type="default">市价单</n-tag>
          </n-descriptions-item>
        </n-descriptions>
        
        <n-divider>止盈止损设置</n-divider>
        
        <n-descriptions :column="2" bordered>
          <n-descriptions-item label="止盈百分比">
            <n-tag v-if="quickOrderConfirmData.settings.takeProfitPercentage" type="success">
              {{ quickOrderConfirmData.settings.takeProfitPercentage }}%
            </n-tag>
            <n-tag v-else type="default">未设置</n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="止损百分比">
            <n-tag v-if="quickOrderConfirmData.settings.stopLossPercentage" type="error">
              {{ quickOrderConfirmData.settings.stopLossPercentage }}%
            </n-tag>
            <n-tag v-else type="default">未设置</n-tag>
          </n-descriptions-item>
        </n-descriptions>
        
        <n-alert type="warning" style="margin-top: 16px;">
          <template #header>
            确认执行快速下单
          </template>
          此操作将使用上述设置对所有{{ quickOrderConfirmData.settings.useAllUsers ? '用户' : '选中用户' }}执行{{ quickOrderConfirmData.side === 'BUY' ? '开多' : '开空' }}操作，请确认无误后点击"确认下单"。
        </n-alert>
      </div>
      
      <template #action>
        <n-button @click="cancelQuickOrder">取消</n-button>
        <n-button 
          type="primary" 
          @click="confirmQuickOrder"
          :loading="quickOrderLoading"
        >
          确认下单
        </n-button>
      </template>
    </n-modal>
  </div>
</template>

<script setup>
import { ref, reactive, computed, h, nextTick, watch, onMounted } from 'vue'
import { NButton, NTooltip, NInputNumber, NSwitch, useNotification } from 'naive-ui'
import axios from 'axios'
import * as XLSX from 'xlsx'

// Props
const props = defineProps({
  apiPrefix: {
    type: String,
    default: '' // 空字符串表示普通接口，'/admin' 表示管理员接口
  },
  currentUser: {
    type: String,
    default: '' // 当前用户名，空字符串表示管理员模式
  }
})

// 定义事件
const emit = defineEmits([
  'coin-added',
  'coin-deleted',
  'table-refreshed',
  'notification-added',
  'row-selection'
])

// 内部状态
const internalCoins = ref([])
const tableData = reactive([])
const timeColumns = ref([])
const selectedRowKeys = ref([])
const supportedCoins = ref([])
const inputValue = ref('')
const soundEnabled = ref(true) // 提示音开关，默认开启
const CELL_WIDTH = 70

// 通知实例
const notification = useNotification()

// 存储已触发的警告，避免重复触发
const triggeredWarnings = ref(new Set())

// 滑动窗口监控（每个币种一个窗口，长度为10）
const slidingWindows = ref(new Map()) // key: coin, value: { data: [{timestamp, value}], windowSize: 10, lastAlertTimestamp: null }

// 滑动窗口提示冷却期（每个币种最后一次提示的时间戳）
const slidingWindowCooldown = ref(new Map()) // key: coin, value: { lastAlertTimestamp: timestamp, cooldownCount: 0 }

// 快速下单确认模态框
const showQuickOrderConfirmModal = ref(false)
const quickOrderLoading = ref(false)
const quickOrderConfirmData = ref({
  coin: '',
  symbol: '',
  side: '',
  positionSide: '',
  settings: null
})

// 从历史数据回填滑动窗口
function fillSlidingWindowFromHistory(coin, row) {
  if (!coin || !row || !row._rawByTime) {
    return
  }
  
  // 获取或创建窗口
  if (!slidingWindows.value.has(coin)) {
    slidingWindows.value.set(coin, {
      data: [],
      windowSize: 10
    })
  }
  
  const window = slidingWindows.value.get(coin)
  
  // 如果窗口已有数据，不需要回填
  if (window.data.length > 0) {
    return
  }
  
  // 从历史数据中获取最近的数据点（按时间排序）
  const historicalData = Object.keys(row._rawByTime)
    .map(timestamp => ({
      timestamp,
      value: row._rawByTime[timestamp]
    }))
    .filter(item => item.value > 0) // 过滤掉无效数据
    .sort((a, b) => a.timestamp.localeCompare(b.timestamp)) // 按时间排序
  
  // 取最后10个数据点填充窗口
  const recentData = historicalData.slice(-window.windowSize)
  
  if (recentData.length > 0) {
    window.data = recentData
    console.log(`[滑动窗口回填] ${coin}: 从历史数据回填了 ${recentData.length} 个数据点`, {
      data: recentData.map(d => ({
        time: d.timestamp,
        value: d.value.toFixed(2)
      }))
    })
  }
}

// 更新滑动窗口并检查条件
function updateSlidingWindow(coin, timestamp, value) {
  if (!coin || !timestamp || !value || value <= 0) {
    return
  }
  
  // 获取或创建窗口
  if (!slidingWindows.value.has(coin)) {
    slidingWindows.value.set(coin, {
      data: [],
      windowSize: 10
    })
  }
  
  const window = slidingWindows.value.get(coin)
  
  // 如果窗口为空，尝试从历史数据回填
  if (window.data.length === 0) {
    // 查找对应的行数据
    const row = tableData.find(r => r.coin === coin)
    if (row) {
      fillSlidingWindowFromHistory(coin, row)
    }
  }
  
  // 检查新数据点是否已存在（避免重复添加）
  const existingIndex = window.data.findIndex(d => d.timestamp === timestamp)
  if (existingIndex !== -1) {
    // 如果已存在，更新值
    window.data[existingIndex].value = value
  } else {
    // 添加新数据点
    window.data.push({ timestamp, value })
    
    // 保持窗口大小不超过10
    if (window.data.length > window.windowSize) {
      window.data.shift() // 移除最旧的数据
    }
  }
  
  // 按时间排序窗口数据（确保顺序正确）
  window.data.sort((a, b) => a.timestamp.localeCompare(b.timestamp))
  
  // 打印窗口情况
  console.log(`[滑动窗口] ${coin}:`, {
    size: window.data.length,
    data: window.data.map(d => ({
      time: d.timestamp,
      value: d.value.toFixed(2)
    })),
    first: window.data[0] ? { time: window.data[0].timestamp, value: window.data[0].value.toFixed(2) } : null,
    last: window.data[window.data.length - 1] ? { time: window.data[window.data.length - 1].timestamp, value: window.data[window.data.length - 1].value.toFixed(2) } : null
  })
  
  // 检查窗口条件（至少需要10个数据点）
  if (window.data.length >= window.windowSize) {
    checkSlidingWindow(coin, window)
  }
}

// 检查滑动窗口条件
function checkSlidingWindow(coin, window) {
  if (window.data.length < window.windowSize) {
    return
  }
  
  const data = window.data
  let riseCount = 0 // 上涨次数
  
  // 统计上涨次数（相邻数据点比较）
  for (let i = 1; i < data.length; i++) {
    if (data[i].value > data[i - 1].value) {
      riseCount++
    }
  }
  
  // 计算尾部比头部的涨幅
  const firstValue = data[0].value
  const lastValue = data[data.length - 1].value
  const risePercent = ((lastValue - firstValue) / firstValue) * 100
  
  // 打印检查结果
  console.log(`[滑动窗口检查] ${coin}:`, {
    riseCount,
    risePercent: risePercent.toFixed(2) + '%',
    firstValue: firstValue.toFixed(2),
    lastValue: lastValue.toFixed(2),
    condition1: riseCount >= 6 ? '✓' : '✗',
    condition2: risePercent > 2 ? '✓' : '✗'
  })
  
  // 检查条件：上涨次数 >= 6 且 尾部比头部涨幅 > 2%
  if (riseCount >= 6 && risePercent > 2) {
    // 检查冷却期：提示一次后10个数据点内不再提示
    const lastAlert = slidingWindowCooldown.value.get(coin)
    const currentTimestamp = data[data.length - 1].timestamp
    
    if (lastAlert) {
      // 计算距离最后一次提示已经过了多少个数据点
      // 从窗口中找到最后一次提示的时间戳位置
      const lastAlertIndex = window.data.findIndex(d => d.timestamp === lastAlert.lastAlertTimestamp)
      
      if (lastAlertIndex !== -1) {
        // 计算从最后一次提示到现在有多少个数据点
        const dataPointsSinceLastAlert = window.data.length - 1 - lastAlertIndex
        
        // 如果还在冷却期内（10个数据点内），不提示
        if (dataPointsSinceLastAlert < 10) {
          console.log(`[滑动窗口冷却] ${coin}: 距离上次提示还有${10 - dataPointsSinceLastAlert}个数据点，跳过提示`)
          return
        }
      } else {
        // 如果最后一次提示的时间戳不在当前窗口中，说明已经过了10个数据点，清除冷却期记录
        console.log(`[滑动窗口冷却] ${coin}: 最后一次提示的时间戳不在当前窗口中，清除冷却期`)
        slidingWindowCooldown.value.delete(coin)
      }
    }
    
    // 触发提示
    const warningKey = `${coin}-sliding-window-${currentTimestamp}`
    
    // 避免重复触发
    if (triggeredWarnings.value.has(warningKey)) {
      return
    }
    
    triggeredWarnings.value.add(warningKey)
    
    // 更新冷却期记录
    slidingWindowCooldown.value.set(coin, {
      lastAlertTimestamp: currentTimestamp,
      cooldownCount: 0
    })
    
    // 创建通知对象（标题改为“涨幅”，内容为“近xx个数据上涨xx次，涨幅为xx%”）
    const notification = {
      id: Date.now() + Math.random(),
      coin,
      timestamp: currentTimestamp,
      type: '涨幅',
      actualValue: risePercent,
      threshold: 2,
      formattedActual: `${risePercent.toFixed(2)}%`,
      formattedThreshold: '2%',
      time: new Date().toLocaleTimeString(),
      riseCount: riseCount,
      windowSize: window.windowSize,
      description: `近${window.windowSize}个数据上涨${riseCount}次，涨幅为${risePercent.toFixed(2)}%`
    }
    
    // 发送通知事件到父组件
    emit('notification-added', notification)
    
    // 播放滑动窗口提示音（与阈值警告音不同）
    if (soundEnabled.value) {
      playSlidingWindowAlertSound()
    }
    
    console.log(`[滑动窗口提示] ${coin}: 上涨次数=${riseCount}, 涨幅=${risePercent.toFixed(2)}%, 已设置冷却期`)
  }
}

// 删除币种的滑动窗口
function removeSlidingWindow(coin) {
  if (slidingWindows.value.has(coin)) {
    slidingWindows.value.delete(coin)
    console.log(`[滑动窗口] 删除币种 ${coin} 的窗口`)
  }
  
  // 同时删除冷却期记录
  if (slidingWindowCooldown.value.has(coin)) {
    slidingWindowCooldown.value.delete(coin)
    console.log(`[滑动窗口冷却] 删除币种 ${coin} 的冷却期记录`)
  }
}

// 触发阈值警告
function triggerThresholdWarning(coin, timestamp, type, actualValue, threshold) {
  const warningKey = `${coin}-${timestamp}-${type}` // 包含时间戳，避免误阻止
  
  // 避免重复触发同一个警告
  if (triggeredWarnings.value.has(warningKey)) {
    return
  }
  
  triggeredWarnings.value.add(warningKey)
  
  // 格式化数值显示
  const formatValue = (value, isPercent, isDropAmount = false) => {
    if (isPercent) {
      return `${value.toFixed(1)}%`
    } else if (isDropAmount) {
      // 跌量阈值直接显示万为单位
      return `${value.toFixed(1)}万`
    } else {
      if (value >= 1e8) {
        return `${(value / 1e8).toFixed(2)}亿`
      } else if (value >= 1e4) {
        return `${(value / 1e4).toFixed(1)}万`
      } else {
        return value.toLocaleString('en-US')
      }
    }
  }
  
  const isPercent = type === '跌幅' || type === '拉升'
  const isDropAmount = type === '跌量'
  const formattedActual = formatValue(actualValue, isPercent)
  const formattedThreshold = formatValue(threshold, isPercent, isDropAmount)
  
  // 创建通知对象
  const notification = {
    id: Date.now() + Math.random(),
    coin,
    timestamp,
    type,
    actualValue,
    threshold,
    formattedActual,
    formattedThreshold,
    time: new Date().toLocaleTimeString()
  }
  
  // 发送通知事件到父组件
  emit('notification-added', notification)
  
  // 播放警告声音
  if (soundEnabled.value) {
    playAlertSound()
  }
}

// 播放警告声音
function playAlertSound() {
  // 检查提示音开关
  if (!soundEnabled.value) {
    return
  }
  
  try {
    // 检查浏览器是否支持Web Audio API
    if (!window.AudioContext && !window.webkitAudioContext) {
      console.warn('浏览器不支持Web Audio API')
      return
    }
    
    const audioContext = new (window.AudioContext || window.webkitAudioContext)()
    
    // 检查音频上下文状态
    if (audioContext.state === 'suspended') {
      // 尝试恢复音频上下文（需要用户交互）
      audioContext.resume().then(() => {
        playSound(audioContext)
      }).catch(err => {
        console.warn('无法恢复音频上下文:', err)
      })
    } else {
      playSound(audioContext)
    }
  } catch (err) {
    console.warn('音频播放失败:', err)
  }
}

// 实际播放声音的函数（阈值警告音：三声短促的"哔"声）
function playSound(audioContext) {
  try {
    const oscillator = audioContext.createOscillator()
    const gainNode = audioContext.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    // 创建更明显的提示音：三声短促的"哔"声（1000Hz）
    oscillator.frequency.setValueAtTime(1000, audioContext.currentTime)
    oscillator.frequency.setValueAtTime(1000, audioContext.currentTime + 0.1)
    oscillator.frequency.setValueAtTime(1000, audioContext.currentTime + 0.2)
    
    gainNode.gain.setValueAtTime(0.5, audioContext.currentTime)
    gainNode.gain.setValueAtTime(0, audioContext.currentTime + 0.1)
    gainNode.gain.setValueAtTime(0.5, audioContext.currentTime + 0.1)
    gainNode.gain.setValueAtTime(0, audioContext.currentTime + 0.2)
    gainNode.gain.setValueAtTime(0.5, audioContext.currentTime + 0.2)
    gainNode.gain.setValueAtTime(0, audioContext.currentTime + 0.3)
    
    oscillator.start(audioContext.currentTime)
    oscillator.stop(audioContext.currentTime + 0.3)
  } catch (err) {
    console.warn('声音播放失败:', err)
  }
}

// 播放滑动窗口提示音（上升音调）
function playSlidingWindowSound(audioContext) {
  try {
    const oscillator = audioContext.createOscillator()
    const gainNode = audioContext.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    // 创建上升音调：从800Hz上升到1200Hz，持续0.4秒
    const startFreq = 800
    const endFreq = 1200
    const duration = 0.4
    
    oscillator.frequency.setValueAtTime(startFreq, audioContext.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(endFreq, audioContext.currentTime + duration)
    
    // 音量渐变：快速上升，然后缓慢下降
    gainNode.gain.setValueAtTime(0, audioContext.currentTime)
    gainNode.gain.linearRampToValueAtTime(0.6, audioContext.currentTime + 0.1)
    gainNode.gain.linearRampToValueAtTime(0.3, audioContext.currentTime + duration)
    
    oscillator.start(audioContext.currentTime)
    oscillator.stop(audioContext.currentTime + duration)
  } catch (err) {
    console.warn('滑动窗口提示音播放失败:', err)
  }
}

// 播放滑动窗口提示音（入口函数）
function playSlidingWindowAlertSound() {
  // 检查提示音开关
  if (!soundEnabled.value) {
    return
  }
  
  try {
    // 检查浏览器是否支持Web Audio API
    if (!window.AudioContext && !window.webkitAudioContext) {
      console.warn('浏览器不支持Web Audio API')
      return
    }
    
    const audioContext = new (window.AudioContext || window.webkitAudioContext)()
    
    // 检查音频上下文状态
    if (audioContext.state === 'suspended') {
      // 尝试恢复音频上下文（需要用户交互）
      audioContext.resume().then(() => {
        playSlidingWindowSound(audioContext)
      }).catch(err => {
        console.warn('无法恢复音频上下文:', err)
      })
    } else {
      playSlidingWindowSound(audioContext)
    }
  } catch (err) {
    console.warn('音频播放失败:', err)
  }
}

// AutoComplete options for the input field
const autoCompleteOptions = computed(() => {
  const query = (inputValue.value || '').trim().toLowerCase()
  const list = Array.isArray(supportedCoins.value) ? supportedCoins.value : []
  if (!query) {
    return list
      .slice(0, 50)
      .map((coin) => ({ label: String(coin), value: String(coin) }))
  }
  const normalized = list.map((c) => String(c))
  const startsWithGroup = []
  const containsGroup = []
  for (const coin of normalized) {
    const lc = coin.toLowerCase()
    if (lc.startsWith(query)) {
      startsWithGroup.push(coin)
    } else if (lc.includes(query)) {
      containsGroup.push(coin)
    }
  }
  startsWithGroup.sort((a, b) => a.localeCompare(b))
  containsGroup.sort((a, b) => a.localeCompare(b))
  const merged = startsWithGroup.concat(containsGroup)
  return merged.slice(0, 50).map((coin) => ({ label: coin, value: coin }))
})

// Function to fetch all supported coins from the backend
async function getAllSupportedCoins() {
  try {
    const res = await axios.get(`${import.meta.env.VITE_API_BASE}/all_coins_support`)
    const data = Array.isArray(res.data) ? res.data : []
    const unique = Array.from(new Set(data.map((c) => String(c))))
    return unique
  } catch (err) {
    return []
  }
}

// localStorage 辅助函数 - 用于 user 模式
function getUserCoinsKey() {
  return `user_coins_${props.currentUser}`
}

function saveUserCoins(coins) {
  if (!props.currentUser) return
  localStorage.setItem(getUserCoinsKey(), JSON.stringify(coins))
}

function loadUserCoins() {
  if (!props.currentUser) return []
  try {
    const stored = localStorage.getItem(getUserCoinsKey())
    return stored ? JSON.parse(stored) : []
  } catch (err) {
    return []
  }
}

function addUserCoin(coin) {
  if (!props.currentUser) return
  const userCoins = loadUserCoins()
  if (!userCoins.includes(coin)) {
    userCoins.push(coin)
    saveUserCoins(userCoins)
  }
}

function removeUserCoin(coin) {
  if (!props.currentUser) return
  const userCoins = loadUserCoins()
  const filtered = userCoins.filter(c => c !== coin)
  saveUserCoins(filtered)
}

// Handle search/add coin
async function onSearch() {
  const value = (inputValue.value || '').trim()
  if (!value) return
  if (supportedCoins.value.length > 0 && !supportedCoins.value.includes(value)) {
    return
  }
  await addCoin(value)
  inputValue.value = ''
}

// 初始化表格数据
function initializeTableData() {
  const initialTime = getSecondLabel()
  const newTableData = internalCoins.value.map(coin => ({ coin, [initialTime]: 0 }))
  tableData.splice(0, tableData.length, ...newTableData)
  timeColumns.value = [initialTime]
}

// 获取当前时间标签
function getSecondLabel() {
  const now = new Date()
  const hh = String(now.getHours()).padStart(2, '0')
  const mm = String(now.getMinutes()).padStart(2, '0')
  const ss = String(now.getSeconds()).padStart(2, '0')
  return `${hh}:${mm}:${ss}`
}

// 解析显示值为数字（支持 '亿'、'万'、纯数字）
function parseDisplayToNumber(v) {
  if (v === undefined || v === null) return NaN
  const str = String(v).trim()
  if (str === '') return NaN
  if (/亿$/.test(str)) {
    const num = Number(str.replace(/亿$/, ''))
    return isNaN(num) ? NaN : num * 1e8
  }
  if (/万$/.test(str)) {
    const num = Number(str.replace(/万$/, ''))
    return isNaN(num) ? NaN : num * 1e4
  }
  const num = Number(str)
  return isNaN(num) ? NaN : num
}

// 将数字格式化为显示用字符串（优先万，其次亿）
function formatDisplayNumber(amount) {
  const num = Number(amount) || 0
  if (num >= 1e8) {
    return (num / 1e8).toFixed(2) + '亿'
  }
  if (num >= 1e4) {
    return (num / 1e4).toFixed(1) + '万'
  }
  return String(num)
}

// 千分位格式化
function formatWithSeparators(amount) {
  const n = Number(amount)
  if (!isFinite(n)) return String(amount)
  return n.toLocaleString('en-US')
}

// 获取单元格背景色
function getCellColor(row, timestamp, isNewData = false) {
  const currentValue = row._rawByTime && row._rawByTime[timestamp]
  if (currentValue === undefined || currentValue === null || currentValue === 0) return ''
  
  // 获取当前时间戳在时间列中的索引
  const currentIndex = timeColumns.value.indexOf(timestamp)
  if (currentIndex === -1) return ''
  
  // 如果是第一个数据点，显示绿色
  if (currentIndex === 0) {
    return 'background-color: #dcfce7;' // 浅绿色
  }
  
  // 获取前一个时间戳的值
  const prevTimestamp = timeColumns.value[currentIndex - 1]
  const prevValue = row._rawByTime && row._rawByTime[prevTimestamp]
  
  if (prevValue === undefined || prevValue === null || prevValue === 0) return ''
  
  // 检查是否超过阈值（只有新数据才触发警告）
  const dropAmount = prevValue - currentValue
  const dropPercent = (dropAmount / prevValue) * 100
  
  // 检查跌量阈值（用户输入的是万为单位，需要转换为实际数值）
  const dropAmountThresholdInWan = row._dropAmountThreshold || 0
  const dropAmountThreshold = dropAmountThresholdInWan * 10000 // 转换为实际数值
  if (dropAmountThreshold > 0 && dropAmount >= dropAmountThreshold) {
    // 触发警告（只有新数据才触发）
    if (isNewData) {
      const warningKey = `${row.coin}-${timestamp}-跌量`
      if (!triggeredWarnings.value.has(warningKey)) {
        triggerThresholdWarning(row.coin, timestamp, '跌量', dropAmount, dropAmountThresholdInWan)
      }
    }
    return 'background-color: #fecaca;' // 浅红色
  }
  
  // 检查跌幅阈值
  if (row._dropPercentThreshold && row._dropPercentThreshold > 0 && dropPercent >= row._dropPercentThreshold) {
    // 触发警告（只有新数据才触发）
    if (isNewData) {
      const warningKey = `${row.coin}-${timestamp}-跌幅`
      if (!triggeredWarnings.value.has(warningKey)) {
        triggerThresholdWarning(row.coin, timestamp, '跌幅', dropPercent, row._dropPercentThreshold)
      }
    }
    return 'background-color: #fecaca;' // 浅红色
  }
  
  // 检查快速拉升（涨幅超过2%）- 仅改变颜色，不弹出通知
  const risePercent = ((currentValue - prevValue) / prevValue) * 100
  if (risePercent >= 2) {
    return 'background-color: #dbeafe;' // 浅蓝色 - 快速拉升提醒
  }
  
  // 如果当前值大于等于前一个值，显示绿色
  if (currentValue >= prevValue) {
    return 'background-color: #dcfce7;' // 浅绿色
  } else {
    return 'background-color: #fef3c7;' // 浅黄色
  }
}

// 批量获取币种位置信息
async function getBatchCoinPositions(coins) {
  try {
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/batch_coin_interest_info` :
      `${import.meta.env.VITE_API_BASE}/batch_coin_interest_info`
    
    const res = await axios.post(endpoint, { coins })
    const data = res.data
    if (data && data.results && Array.isArray(data.results)) {
      // 将结果转换为以币种为key的对象，方便查找
      const resultMap = {}
      data.results.forEach(item => {
        resultMap[item.coin] = {
          value: Number(item.value) || 0,
          timestamp: item.timestamp,
          dataCount: item.data_count || 0,
          isMonitored: item.is_monitored || false
        }
      })
      return resultMap
    }
    return {}
  } catch (err) {
    return {}
  }
}

// 获取币的历史信息（起始时间和初始价格）
async function fetchCoinInfo(coin) {
  try {
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/data/${coin}` :
      `${import.meta.env.VITE_API_BASE}/pool/data/${coin}`
    
    const res = await axios.get(endpoint)
    const data = res.data
    
    // 检查后端返回的 time 字段
    if (data.time === 'new') {
      // 新添加的币，不设置基准，等待第一次实时数据
      console.log(`${coin} 标记为新币，不设置基准`)
      return null
    }
    
    // 如果有具体时间，使用该时间对应的数据点作为基准
    if (data.time && data.series && Array.isArray(data.series)) {
      const targetPoint = data.series.find(([timestamp, price]) => timestamp === data.time)
      if (targetPoint) {
        const [time, price] = targetPoint
        console.log(`${coin} 使用后端指定的基准时间: ${time}, 价格: ${price}`)
        return {
          time: time,
          value: formatDisplayNumber(price),
          baseline: price
        }
      }
    }
    
    // 兼容旧版本：如果没有 time 字段，使用第一个数据点
    if (data.series && Array.isArray(data.series) && data.series.length > 0) {
      const firstPoint = data.series[0]
      if (Array.isArray(firstPoint) && firstPoint.length >= 2) {
        const [time, price] = firstPoint
        return {
          time: time,
          value: formatDisplayNumber(price),
          baseline: price
        }
      }
    }
    
    return null
  } catch (err) {
    return null
  }
}

// 加载新币的历史数据
async function loadNewCoinHistoricalData(row) {
  try {
    console.log(`开始加载币种 ${row.coin} 的历史数据...`)
    
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/persistent_data/${row.coin}` :
      `${import.meta.env.VITE_API_BASE}/pool/persistent_data/${row.coin}`
    
    const response = await axios.get(endpoint)
    const data = response.data
    
    if (data && data.series && Array.isArray(data.series)) {
      console.log(`获取到 ${row.coin} 的历史数据:`, data.series.length, '条记录')
      
      // 加载全部历史数据（不再限制1小时）
      console.log(`加载全部历史数据:`, data.series.length, '条记录')
      
      // 将历史数据填充到行中
      data.series.forEach(([timestamp, price]) => {
        // 确保时间戳在 timeColumns 中
        if (!timeColumns.value.includes(timestamp)) {
          timeColumns.value.push(timestamp)
        }
        
        // 填充数据
        if (!row._rawByTime) row._rawByTime = {}
        row._rawByTime[timestamp] = price
        row[timestamp] = formatDisplayNumber(price)
      })
      
      // 重新构建列定义以包含新的时间列
      await rebuildColumnsWithTimeData()
      
      console.log(`币种 ${row.coin} 历史数据加载完成`)
    }
  } catch (error) {
    console.error(`加载币种 ${row.coin} 历史数据失败:`, error)
  }
}

// 重新构建列定义以包含时间数据
async function rebuildColumnsWithTimeData() {
  // 收集所有行中实际存在的时间戳（从 _rawByTime 和行属性中收集）
  const allTimeStamps = new Set(timeColumns.value)
  
  // 遍历所有行，收集它们的时间戳
  tableData.forEach(row => {
    // 从 _rawByTime 中收集时间戳（最可靠的数据源）
    if (row._rawByTime && typeof row._rawByTime === 'object') {
      Object.keys(row._rawByTime).forEach(timestamp => {
        allTimeStamps.add(timestamp)
      })
    }
    
    // 也从行对象本身收集时间戳属性（排除已知的特殊属性）
    const specialKeys = new Set([
      'coin', '_rawByTime', '_dropAmountThreshold', '_dropPercentThreshold',
      '_firstCapture', '_latestTimestamp', '_dataCount', '_isMonitored',
      '_needsReload', '_changePercent'
    ])
    
    Object.keys(row).forEach(key => {
      if (!specialKeys.has(key)) {
        // 检查是否是时间戳格式（包含冒号或符合时间戳格式）
        // 时间戳格式可能是：'21:41:04' 或 'K21:41:04' 等
        if (typeof key === 'string' && key.includes(':')) {
          allTimeStamps.add(key)
        }
      }
    })
  })
  
  // 按时间排序
  const sortedTimes = Array.from(allTimeStamps).sort()
  timeColumns.value = sortedTimes
  
  // 重建列定义
  const newColumns = [
    selectionColumn, // 添加选择列
    {
      title: '币种',
      key: 'coin',
      fixed: 'left',
      width: CELL_WIDTH * 1.5, // 105px
      sorter: (rowA, rowB) => {
        const percentA = typeof rowA._changePercent === 'number' && isFinite(rowA._changePercent) ? rowA._changePercent : 0
        const percentB = typeof rowB._changePercent === 'number' && isFinite(rowB._changePercent) ? rowB._changePercent : 0
        return percentB - percentA // 降序排列，涨幅大的在前
      },
      render: (row) => {
        const pct = typeof row._changePercent === 'number' && isFinite(row._changePercent)
          ? row._changePercent
          : null
        
        const changePercentElement = pct !== null ? (() => {
          const color = pct >= 0 ? '#16a34a' : '#dc2626'
          return h('span', { style: { color, fontWeight: 'bold' } }, `${pct >= 0 ? '+' : ''}${pct.toFixed(2)}%`)
        })() : h('span', { style: { color: '#6b7280' } }, '--')
        
        return h('div', { style: { display: 'flex', flexDirection: 'column', gap: '2px' } }, [
          h('span', { style: { fontWeight: 'bold' } }, row.coin),
          changePercentElement
        ])
      }
    }
  ]
  
  // 添加时间列
  sortedTimes.forEach(time => {
    newColumns.push({
      title: time.replace(/^[A-Z]/, ''), // 去掉字母前缀
      key: time,
      width: CELL_WIDTH,
      render: (row) => {
        const cellStyle = getCellColor(row, time, false) // 历史数据，不触发警告
        
        // 确保显示值不为 undefined
        const displayValue = row[time] !== undefined ? row[time] : '0'
        const rawValue = row._rawByTime && row._rawByTime[time] !== undefined ? row._rawByTime[time] : 0
        
        return h(
          NTooltip,
          { placement: 'top' },
          {
            trigger: () => h('span', { style: cellStyle }, displayValue),
            default: () => formatWithSeparators(rawValue)
          }
        )
      }
    })
  })
  
  // 添加阈值列和操作列
  newColumns.push(thresholdsColumn, actionColumn)
  
  columns.value = newColumns
  updateScrollX()
}

// 从后端池获取当前币列表
async function fetchPoolCoins() {
  try {
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/coins` :
      `${import.meta.env.VITE_API_BASE}/pool/coins`
    
    const res = await axios.get(endpoint)
    let list = Array.isArray(res.data && res.data.coins) ? res.data.coins : []
    list = list.map((c) => String(c))
    
    // user 模式：只返回该用户添加的币种
    if (props.currentUser) {
      const userCoins = loadUserCoins()
      list = list.filter(coin => userCoins.includes(coin))
    }
    
    return list
  } catch (err) {
    return []
  }
}

// 恢复所有币的历史数据并重建时间列
async function restoreHistoricalData() {
  const allTimePoints = new Set()
  
  // 为每个币获取历史数据
  for (const row of tableData) {
    if (!row._firstCapture) {
      const coinInfo = await fetchCoinInfo(row.coin)
      if (coinInfo) {
        row._firstCapture = coinInfo
      }
    }
    
    // 获取完整的历史数据系列（添加超时和错误处理）
    try {
      const endpoint = props.apiPrefix ? 
        `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/data/${row.coin}` :
        `${import.meta.env.VITE_API_BASE}/pool/data/${row.coin}`
      
      const res = await axios.get(endpoint, { timeout: 5000 }) // 5秒超时
      const data = res.data
      if (data && data.series && Array.isArray(data.series)) {
        data.series.forEach(([time, price]) => {
          allTimePoints.add(time)
          // 填充历史数据到行中
          if (!row._rawByTime) row._rawByTime = {}
          row._rawByTime[time] = price
          row[time] = formatDisplayNumber(price)
        })
      }
    } catch (err) {
      // 不抛出错误，继续处理其他币种
    }
  }
  
  // 重建时间列（按时间顺序）
  const sortedTimes = Array.from(allTimePoints).sort();
  timeColumns.value = sortedTimes
  
  // 恢复历史数据后，回填所有币种的滑动窗口
  for (const row of tableData) {
    if (row._rawByTime && Object.keys(row._rawByTime).length > 0) {
      fillSlidingWindowFromHistory(row.coin, row)
    }
  }
  
  // 重建列定义
  const newColumns = [
    selectionColumn, // 添加选择列
    {
      title: '币种',
      key: 'coin',
      fixed: 'left',
      width: CELL_WIDTH * 1.5, // 105px
      sorter: (rowA, rowB) => {
        const percentA = typeof rowA._changePercent === 'number' && isFinite(rowA._changePercent) ? rowA._changePercent : 0
        const percentB = typeof rowB._changePercent === 'number' && isFinite(rowB._changePercent) ? rowB._changePercent : 0
        return percentB - percentA // 降序排列，涨幅大的在前
      },
      render: (row) => {
        const pct = typeof row._changePercent === 'number' && isFinite(row._changePercent)
          ? row._changePercent
          : null
        
        const changePercentElement = pct !== null ? (() => {
          const abs = Math.abs(pct)
          const zeroish = abs < 0.0001
          const color = zeroish ? '#000' : (pct > 0 ? '#16a34a' : '#dc2626')
          const text = `${zeroish ? '0.0' : pct.toFixed(1)}%`
          return h('span', { 
            style: `margin-left: 8px; color: ${color}; font-size: 12px; white-space: nowrap; line-height: 1.2;` 
          }, text)
        })() : null
        
        const firstCaptureElement = row._firstCapture ? h('div', { class: 'first-label' }, [
          h('div', null, row._firstCapture.time),
          h('div', null, row._firstCapture.value)
        ]) : null
        
        return h('div', { class: 'coin-cell' }, [
          h('div', { class: 'coin-name-line' }, [
            h('span', { class: 'coin-name' }, row.coin),
            changePercentElement
          ]),
          firstCaptureElement
        ])
      }
    }
  ]
  
  // 添加时间列
  sortedTimes.forEach(time => {
    newColumns.push({
      title: time.replace(/^[A-Z]/, ''), // 去掉字母前缀
      key: time,
      width: CELL_WIDTH,
      render: (row) => {
        const cellStyle = getCellColor(row, time, false) // 历史数据，不触发警告
        
        // 确保显示值不为 undefined
        const displayValue = row[time] !== undefined ? row[time] : '0'
        const rawValue = row._rawByTime && row._rawByTime[time] !== undefined ? row._rawByTime[time] : 0
        
        return h(
          NTooltip,
          { placement: 'top' },
          {
            trigger: () => h('span', { style: cellStyle }, displayValue),
            default: () => formatWithSeparators(rawValue)
          }
        )
      }
    })
  })
  
  // 添加阈值列和操作列
  newColumns.push(thresholdsColumn)
  newColumns.push(actionColumn)
  columns.value = newColumns
}

// 重建表格
async function rebuildTableForCoins(newCoins) {
  internalCoins.value = newCoins
  
  // 重建表格数据
  const newTableData = []
  for (const coin of internalCoins.value) {
    const row = { 
      coin, 
      _rawByTime: {},
      _dropAmountThreshold: 0,
      _dropPercentThreshold: 2 // 默认跌幅阈值2%
    }
    
    // 为所有现有时间列初始化为 '0'
    timeColumns.value.forEach((timestamp) => {
      row[timestamp] = '0'
      row._rawByTime[timestamp] = 0
    })
    
    newTableData.push(row)
  }
  tableData.splice(0, tableData.length, ...newTableData)
}

// 防抖刷新函数
let refreshTimeout = null
const debouncedRefresh = () => {
  if (refreshTimeout) clearTimeout(refreshTimeout)
  refreshTimeout = setTimeout(refreshTable, 100) // 100ms防抖
}

// 刷新标志，防止重复执行
let isRefreshing = false

// 刷新表格
async function refreshTable() {
  // 如果正在刷新，直接返回，避免重复请求
  if (isRefreshing) {
    console.log('refreshTable 正在执行，跳过重复调用')
    return
  }
  
  try {
    isRefreshing = true
    
    // 如果管理员列表为空，直接返回
    if (internalCoins.value.length === 0) {
      console.log('管理员列表为空，跳过数据请求')
      return
    }
    
    // 批量请求所有币（返回新格式数据）
    const batchResults = await getBatchCoinPositions(internalCoins.value)
    const results = internalCoins.value.map(coin => batchResults[coin] || { value: 0, timestamp: null, dataCount: 0, isMonitored: false })

    // 收集所有新的时间戳
    const newTimestamps = new Set()
    
    // 检查是否有新币种第一次有数据，需要重新加载
    let needsReload = false
    
    // 更新表格数据
    tableData.forEach((row, idx) => {
      const coinData = results[idx]
      const { value: raw, timestamp, dataCount, isMonitored } = coinData
      
      // 检查时间是否比当前最新时间更新
      const shouldUpdate = timestamp && (!row._latestTimestamp || timestamp > row._latestTimestamp)
      
      if (shouldUpdate) {
        // 数据更新逻辑
      }
      
      if (shouldUpdate) {
        const display = formatDisplayNumber(raw)
        
        // 使用后端返回的时间戳作为列名
        row[timestamp] = display
        // 保存原始值用于 tooltip 与涨跌计算
        if (!row._rawByTime) row._rawByTime = {}
        row._rawByTime[timestamp] = raw
        
        // 更新最新时间戳
        row._latestTimestamp = timestamp
        row._dataCount = dataCount
        row._isMonitored = isMonitored
        
        // 收集新的时间戳
        if (!timeColumns.value.includes(timestamp)) {
          newTimestamps.add(timestamp)
        }
        
        // 如果是新添加的币种第一次有数据，标记需要重新加载
        if (row._needsReload && raw > 0) {
          needsReload = true
          row._needsReload = false // 清除标记
        }
        
        // 如果 _firstCapture 不存在且有有效数据，设置基准（首次数据）
        if (!row._firstCapture && raw > 0) {
          // 对于新添加的币种，需要判断这是否是历史时间戳
          // 判断逻辑：
          // 1. 如果时间戳不在历史数据中，是新数据，应该设置基准
          // 2. 如果时间戳在历史数据中存在，需要检查：
          //    - 如果这是当前最新的时间戳（比之前的 _latestTimestamp 更新），说明这是实时数据，应该设置基准
          //    - 如果这不是最新的时间戳，说明是历史数据，不设置基准，等待新的实时数据
          const historicalValue = row._rawByTime && row._rawByTime[timestamp]
          const isHistoricalTimestamp = historicalValue !== undefined
          
          // 检查这是否是当前最新的时间戳（实时数据）
          const isLatestTimestamp = !row._latestTimestamp || timestamp >= row._latestTimestamp
          
          if (!isHistoricalTimestamp) {
            // 这是一个新的时间戳，可以作为基准
            row._firstCapture = {
              time: timestamp,
              value: display,
              baseline: raw
            }
            console.log(`${row.coin} 首次数据，设置基准时间: ${timestamp}, 基准价格: ${raw}`)
          } else if (isLatestTimestamp) {
            // 时间戳在历史数据中存在，但这是最新的时间戳（实时数据），应该设置基准
            row._firstCapture = {
              time: timestamp,
              value: display,
              baseline: raw
            }
            console.log(`${row.coin} 首次数据（实时数据），设置基准时间: ${timestamp}, 基准价格: ${raw}`)
          } else {
            // 这是历史时间戳且不是最新的，可能是竞态条件导致的重复请求，不设置基准，等待新的实时数据
            console.log(`${row.coin} 跳过历史时间戳作为基准: ${timestamp}, 等待新的实时数据`)
          }
        }
        
        // 计算相对首次值的涨跌百分比
        if (row._firstCapture && raw > 0) {
          const baseline = typeof row._firstCapture.baseline === 'number' && isFinite(row._firstCapture.baseline)
            ? row._firstCapture.baseline
            : parseDisplayToNumber(row._firstCapture.value)
          const current = raw
          if (isFinite(baseline) && baseline !== 0 && isFinite(current) && current > 0) {
            row._changePercent = ((current - baseline) / baseline) * 100
          } else {
            row._changePercent = undefined
          }
        }
        
        // 更新滑动窗口
        updateSlidingWindow(row.coin, timestamp, raw)
      }
    })
    
    // 如果有新币种第一次有数据，触发重新加载
    if (needsReload) {
      const serverCoins = await fetchPoolCoins()
      await rebuildTableForCoins(serverCoins)
      await restoreHistoricalData()
      
      // 立即再调用一次 refreshTable，为新币设置 _firstCapture
      // 第二次调用时 needsReload = false，会正常执行设置逻辑
      // 注意：需要先重置标志，否则递归调用会被跳过
      isRefreshing = false
      await refreshTable()
      return
    }

    // 添加新时间戳列（去重后）
    const sortedNewTimestamps = Array.from(newTimestamps).sort();
    sortedNewTimestamps.forEach(timestamp => {
      const newCol = {
        title: timestamp.replace(/^[A-Z]/, ''), // 去掉字母前缀
        key: timestamp,
        width: CELL_WIDTH,
        render: (row) => {
          // 检查这个时间戳是否真的是新数据（比最新时间戳更新）
          const isReallyNewData = row._latestTimestamp === timestamp
          const cellStyle = getCellColor(row, timestamp, isReallyNewData)
          
          // 确保显示值不为 undefined
          const displayValue = row[timestamp] !== undefined ? row[timestamp] : '0'
          const rawValue = row._rawByTime && row._rawByTime[timestamp] !== undefined ? row._rawByTime[timestamp] : 0
          
          return h(
            NTooltip,
            { placement: 'top' },
            {
              trigger: () => h('span', { style: cellStyle }, displayValue),
              default: () => formatWithSeparators(rawValue)
            }
          )
        }
      };
      const last = columns.value[columns.value.length - 1];
      const secondLast = columns.value[columns.value.length - 2];
      
      // 如果最后两列是阈值列和操作列，则在阈值列之前插入新列
      if (last && last.key === 'actions' && secondLast && secondLast.key === 'thresholds') {
        columns.value.splice(columns.value.length - 2, 0, newCol);
      } else if (last && last.key === 'actions') {
        columns.value.splice(columns.value.length - 1, 0, newCol);
      } else {
        columns.value.push(newCol);
      }
      timeColumns.value.push(timestamp);
    });
    
    // 更新滚动宽度
    updateScrollX();
    
    // 如果有新列，滚动到最右侧
    if (sortedNewTimestamps.length > 0) {
      await scrollToRightMost()
    }
    
    emit('table-refreshed')
  } finally {
    isRefreshing = false
  }
}

// 检查服务器币列表是否有变化
async function checkServerCoinsSync() {
  try {
    // fetchPoolCoins 已经包含了 user 模式的过滤逻辑
    const serverCoins = await fetchPoolCoins()
    const currentCoins = internalCoins.value.map(c => String(c)).sort()
    const serverCoinsSorted = serverCoins.sort()
    
    // 比较币列表是否有变化
    if (JSON.stringify(currentCoins) !== JSON.stringify(serverCoinsSorted)) {
      
      // 找出新增和删除的币种
      const addedCoins = serverCoins.filter(coin => !internalCoins.value.includes(coin))
      const removedCoins = internalCoins.value.filter(coin => !serverCoins.includes(coin))
      
      // 删除被移除的币种
      removedCoins.forEach(coin => {
        const idx = internalCoins.value.indexOf(coin)
        if (idx !== -1) internalCoins.value.splice(idx, 1)
        const rowIdx = tableData.findIndex((r) => r.coin === coin)
        if (rowIdx !== -1) tableData.splice(rowIdx, 1)
        
        // 删除币种的滑动窗口
        removeSlidingWindow(coin)
        
        // user 模式：同时从 localStorage 中删除
        if (props.currentUser) {
          removeUserCoin(coin)
        }
      })
      
      // 添加新币种
      for (const coin of addedCoins) {
        if (!internalCoins.value.includes(coin)) {
          internalCoins.value.push(coin)
          const newRow = { 
            coin, 
            _rawByTime: {},
            _dropAmountThreshold: 0,
            _dropPercentThreshold: 2 // 默认跌幅阈值2%
          }
          // 为已有时间列初始化为 0
          timeColumns.value.forEach((t) => {
            newRow[t] = '0'
            newRow._rawByTime[t] = 0
          })
          tableData.push(newRow)
          
          // 不设置 _firstCapture，等待第一次实时数据
          // 这样无论是新币还是重新加入的币种，都会等待下一个新数据出现才确定时间
          // const coinInfo = await fetchCoinInfo(coin)  // 注释掉：不使用历史数据的时间基准
          // if (coinInfo) {
          //   newRow._firstCapture = coinInfo
          // }
          
          // 标记为需要重新加载的币种
          newRow._needsReload = true
        }
      }
      
      // 通知父组件币列表变化
      emit('update:coins', [...internalCoins.value])
    }
  } catch (err) {
    // 静默处理同步错误
  }
}

// 添加币种
async function addCoin(value) {
  const endpoint = props.apiPrefix ? 
    `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/coins` :
    `${import.meta.env.VITE_API_BASE}/pool/coins`
  
  return axios.post(endpoint, { coin: value })
    .then(async () => {
      // user 模式：保存到 localStorage
      if (props.currentUser) {
        addUserCoin(value)
      }
      
      // 只添加新币到现有表格，保持历史数据
      if (!internalCoins.value.includes(value)) {
        internalCoins.value.push(value)
        const newRow = { 
          coin: value, 
          _rawByTime: {},
          _dropAmountThreshold: 0,
          _dropPercentThreshold: 2 // 默认跌幅阈值2%
        }
        // 为已有时间列初始化为 0
        timeColumns.value.forEach((t) => {
          newRow[t] = '0'
          newRow._rawByTime[t] = 0
        })
        tableData.push(newRow)
        
        // 加载历史数据用于显示，但不设置 _firstCapture
        // 这样无论是新币还是重新加入的币种，都会等待下一个新数据出现才确定时间基准
        await loadNewCoinHistoricalData(newRow)
        
        // 标记为需要重新加载的币种
        newRow._needsReload = true
        
        // 通知父组件币种已添加
        emit('coin-added', value)
      }
      await refreshTable()
    })
    .catch((err) => {
      // 静默处理错误
      throw err
    })
}

// 快速开多
function quickOpenLong(coin) {
  console.log('快速开多:', coin)
  const symbol = coin.endsWith('USDT') ? coin : `${coin}USDT`
  
  // 加载快速下单设置
  const savedSettings = localStorage.getItem('quickOrderSettings')
  if (!savedSettings) {
    alert('请先设置快速下单参数')
    return
  }
  
  const settings = JSON.parse(savedSettings)
  
  // 设置确认数据
  quickOrderConfirmData.value = {
    coin: coin,
    symbol: symbol,
    side: 'BUY',
    positionSide: 'LONG',
    settings: settings
  }
  
  // 显示确认模态框
  showQuickOrderConfirmModal.value = true
}

// 快速开空
function quickOpenShort(coin) {
  console.log('快速开空:', coin)
  const symbol = coin.endsWith('USDT') ? coin : `${coin}USDT`
  
  // 加载快速下单设置
  const savedSettings = localStorage.getItem('quickOrderSettings')
  if (!savedSettings) {
    alert('请先设置快速下单参数')
    return
  }
  
  const settings = JSON.parse(savedSettings)
  
  // 设置确认数据
  quickOrderConfirmData.value = {
    coin: coin,
    symbol: symbol,
    side: 'SELL',
    positionSide: 'SHORT',
    settings: settings
  }
  
  // 显示确认模态框
  showQuickOrderConfirmModal.value = true
}

// 确认执行快速下单
async function confirmQuickOrder() {
  try {
    quickOrderLoading.value = true
    const { symbol, side, positionSide } = quickOrderConfirmData.value
    await executeQuickOrder(symbol, side, positionSide)
    showQuickOrderConfirmModal.value = false
  } catch (error) {
    console.error('快速下单失败:', error)
    alert('快速下单失败: ' + error.message)
  } finally {
    quickOrderLoading.value = false
  }
}

// 取消快速下单
function cancelQuickOrder() {
  showQuickOrderConfirmModal.value = false
  quickOrderConfirmData.value = {
    coin: '',
    symbol: '',
    side: '',
    positionSide: '',
    settings: null
  }
}

// 执行快速下单
async function executeQuickOrder(symbol, side, positionSide) {
  try {
    // 从localStorage加载快速下单设置
    const savedSettings = localStorage.getItem('quickOrderSettings')
    if (!savedSettings) {
      alert('请先设置快速下单参数')
      return
    }
    
    const settings = JSON.parse(savedSettings)
    console.log('加载快速下单设置:', settings)
    
    // 验证设置
    if (!settings.leverage || settings.leverage <= 0) {
      alert('快速下单设置中杠杆倍数无效')
      return
    }
    
    if (!settings.positionPercentage || settings.positionPercentage <= 0) {
      alert('快速下单设置中仓位百分比无效')
      return
    }
    
    // 获取用户列表
    const usersResponse = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/users`)
    if (!usersResponse.data?.success || !usersResponse.data?.data?.users) {
      throw new Error('获取用户列表失败')
    }
    
    const allUsers = usersResponse.data.data.users
    
    // 根据设置确定目标用户
    let targetUsers = []
    if (settings.useAllUsers) {
      targetUsers = allUsers
    } else if (settings.selectedUsers && settings.selectedUsers.length > 0) {
      targetUsers = allUsers.filter(user => settings.selectedUsers.includes(user.id))
    } else {
      alert('快速下单设置中未选择用户')
      return
    }
    
    if (targetUsers.length === 0) {
      alert('没有可用的用户')
      return
    }
    
    // 获取用户余额信息
    const positionsResponse = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/positions/all`)
    if (!positionsResponse.data?.success || !positionsResponse.data?.data?.users) {
      throw new Error('获取用户余额失败')
    }
    
    const usersWithBalance = positionsResponse.data.data.users
    
    // 计算每个用户的下单金额
    const userOrders = []
    const quantities = []
    
    for (const user of targetUsers) {
      // 查找用户的余额信息
      const userBalance = usersWithBalance.find(u => u.alias === user.alias)
      if (!userBalance) {
        console.warn(`用户 ${user.alias} 没有余额信息，跳过`)
        continue
      }
      
      // 查找USDT钱包资产
      const walletAsset = userBalance.positions?.find(pos => pos.type === 'wallet' && pos.asset === 'USDT')
      if (!walletAsset) {
        console.warn(`用户 ${user.alias} 没有USDT钱包，跳过`)
        continue
      }
      
      const availableBalance = parseFloat(walletAsset.availableBalance) || 0
      if (availableBalance <= 0) {
        console.warn(`用户 ${user.alias} 可用余额为0，跳过`)
        continue
      }
      
      // 计算下单金额
      const orderAmount = (availableBalance * settings.positionPercentage) / 100
      
      userOrders.push({
        user_id: user.id,
        amount: Math.round(orderAmount * 100) / 100 // 保留2位小数
      })
      quantities.push(Math.round(orderAmount * 100) / 100)
    }
    
    if (userOrders.length === 0) {
      alert('没有用户满足下单条件（余额不足）')
      return
    }
    
    // 构建API请求数据
    const requestData = {
      symbol: symbol,
      side: side,
      position_side: positionSide,
      user_ids: userOrders.map(order => order.user_id),
      quantities: quantities,
      leverage: settings.leverage,
      type: 'MARKET',
      use_testnet: false,
      is_fast_order: true,
      fast_order_tp_percentage: settings.takeProfitPercentage || 0,
      fast_order_sl_percentage: settings.stopLossPercentage || 0
    }
    
    console.log('快速下单请求:', requestData)
    
    // 调用批量下单API
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/orders/batch_all`, requestData)
    
    console.log('快速下单响应:', response.data)
    
    if (response.data && response.data.success) {
      const data = response.data.data
      
      // 统计成功和失败
      let successCount = 0
      let failedCount = 0
      const successUsers = []
      const failedUsers = []
      
      data.results.forEach(result => {
        if (result.success === true) {
          successCount++
          const mainOrder = result.result?.main_order
          const tpOrder = result.result?.tp_order
          const slOrder = result.result?.sl_order
          
          successUsers.push({
            alias: result.alias,
            mainOrderId: mainOrder?.orderId,
            mainStatus: mainOrder?.status,
            mainPrice: mainOrder?.price,
            executedQty: mainOrder?.executedQty,
            quantity: result.result?.quantity,
            priceUsed: result.result?.price_used,
            side: result.result?.side,
            positionSide: result.result?.position_side,
            leverage: result.result?.leverage,
            tpOrderId: tpOrder?.orderId,
            tpStatus: tpOrder?.status,
            tpPrice: tpOrder?.stopPrice,
            slOrderId: slOrder?.orderId,
            slStatus: slOrder?.status,
            slPrice: slOrder?.stopPrice
          })
        } else {
          failedCount++
          failedUsers.push({
            alias: result.alias,
            error: result.result?.msg || result.message || `错误代码: ${result.status_code || '未知'}`
          })
        }
      })
      
      // 构建结果消息
      let resultMessage = `快速${side === 'BUY' ? '开多' : '开空'}完成！\n`
      resultMessage += `交易对: ${data.symbol}\n`
      resultMessage += `方向: ${data.side === 'BUY' ? '开多' : '开空'}\n`
      resultMessage += `杠杆: ${data.leverage}x\n`
      resultMessage += `目标用户数: ${data.results.length}\n`
      resultMessage += `成功: ${successCount}个，失败: ${failedCount}个\n\n`
      
      if (data.take_profit_price) {
        resultMessage += `止盈价格: $${data.take_profit_price}\n`
      }
      if (data.stop_loss_price) {
        resultMessage += `止损价格: $${data.stop_loss_price}\n`
      }
      if (data.take_profit_price || data.stop_loss_price) {
        resultMessage += '\n'
      }
      
      if (successUsers.length > 0) {
        resultMessage += '成功详情:\n'
        successUsers.forEach(user => {
          resultMessage += `• ${user.alias}:\n`
          resultMessage += `  主订单ID: ${user.mainOrderId}\n`
          resultMessage += `  状态: ${user.mainStatus}\n`
          resultMessage += `  数量: ${user.quantity} ${data.symbol.replace('USDT', '')}\n`
          resultMessage += `  使用价格: $${user.priceUsed}\n`
          resultMessage += `  方向: ${user.side}\n`
          resultMessage += `  仓位方向: ${user.positionSide}\n`
          resultMessage += `  杠杆: ${user.leverage}x\n`
          
          if (user.tpOrderId) {
            resultMessage += `  止盈订单ID: ${user.tpOrderId}\n`
            resultMessage += `  止盈价格: $${user.tpPrice}\n`
          }
          if (user.slOrderId) {
            resultMessage += `  止损订单ID: ${user.slOrderId}\n`
            resultMessage += `  止损价格: $${user.slPrice}\n`
          }
        })
      }
      
      if (failedUsers.length > 0) {
        resultMessage += '\n失败详情:\n'
        failedUsers.forEach(user => {
          resultMessage += `• ${user.alias}: ${user.error}\n`
        })
      }
      
      alert(resultMessage)
      
    } else {
      throw new Error(response.data?.message || '快速下单失败')
    }
    
  } catch (error) {
    console.error('快速下单执行失败:', error)
    throw error
  }
}

// 删除币种
async function deleteCoin(coin) {
  const endpoint = props.apiPrefix ? 
    `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/coins/${coin}` :
    `${import.meta.env.VITE_API_BASE}/pool/coins/${coin}`
  
  return axios.delete(endpoint)
    .then(async () => {
      // 只删除对应币种，保持其他历史数据
      const idx = internalCoins.value.indexOf(coin)
      if (idx !== -1) internalCoins.value.splice(idx, 1)
      const rowIdx = tableData.findIndex((r) => r.coin === coin)
      if (rowIdx !== -1) tableData.splice(rowIdx, 1)
      
      // 删除币种的滑动窗口
      removeSlidingWindow(coin)
      
      // 通知父组件币列表变化和删除事件
      emit('update:coins', [...internalCoins.value])
      emit('coin-deleted', coin)
      
      await refreshTable()
    })
    .catch((err) => {
      // 静默处理错误
      throw err
    })
}

// 查找可滚动的元素
function findScrollableXElement(root) {
  if (!root) return null
  // If root itself scrolls horizontally
  if (root.scrollWidth > root.clientWidth) return root
  // Search descendants breadth-first
  const queue = Array.from(root.children || [])
  while (queue.length) {
    const el = queue.shift()
    if (el && el.scrollWidth > el.clientWidth) return el
    if (el && el.children && el.children.length) queue.push(...el.children)
  }
  return null
}

// 滚动到最右侧
async function scrollToRightMost() {
  await nextTick()
  const root = (dataTableRef.value && dataTableRef.value.$el) || tableWrapperRef.value
  const el = findScrollableXElement(root)
  if (el) {
    const maxLeft = Math.max(0, el.scrollWidth - el.clientWidth)
    try {
      el.scrollTo({ left: maxLeft, behavior: 'smooth' })
    } catch (_) {
      el.scrollLeft = maxLeft
    }
  }
}

// 阈值列定义
const thresholdsColumn = {
  title:     h('div', { style: 'text-align: center; font-size: 11px;' }, [
      h('div', '阈值设置'),
      h('div', { style: 'display: flex; justify-content: space-between; margin-top: 2px; font-size: 10px; color: #666;' }, [
        h('span', '跌量(万)'),
        h('span', '跌幅%')
      ])
    ]),
  key: 'thresholds',
  fixed: 'right',
  width: CELL_WIDTH * 2, // 140px
  render: (row) => {
    return h('div', { 
      style: 'display: flex; gap: 4px; align-items: center; padding: 2px;' 
    }, [
        h(NInputNumber, {
          value: row._dropAmountThreshold || 0,
          'onUpdate:value': (value) => {
            row._dropAmountThreshold = value || 0
          },
          size: 'small',
          min: 0,
          precision: 0,
          placeholder: '跌量(万)',
          style: 'width: 60px;',
          showButton: false
        }),
      h(NInputNumber, {
        value: row._dropPercentThreshold || 2,
        'onUpdate:value': (value) => {
          row._dropPercentThreshold = value || 2
        },
        size: 'small',
        min: 0,
        max: 100,
        precision: 1,
        placeholder: '跌幅%',
        style: 'width: 60px;',
        showButton: false
      })
    ])
  }
}

// 操作列定义
const actionColumn = {
  title: '操作',
  key: 'actions',
  fixed: 'right',
  width: CELL_WIDTH * 3, // 增加宽度以容纳更多按钮
  render: (row) => {
    // user 模式：不显示任何操作按钮
    if (localStorage.getItem('currentUser') !== '') {
      if(props.apiPrefix === '/admin') {
        return null
      } else {
        return h('div', { 
      style: 'display: flex; gap: 4px; align-items: center;' 
    }, [
      h(
        NButton,
        {
          size: 'small',
          type: 'error',
          onClick: () => deleteCoin(row.coin)
        },
        { default: () => '删除' }
      )
    ])
      }
    }
    
    return h('div', { 
      style: 'display: flex; gap: 4px; align-items: center;' 
    }, [
      h(
        NButton,
        {
          size: 'small',
          type: 'success',
          onClick: () => quickOpenLong(row.coin)
        },
        { default: () => '快速开多' }
      ),
      h(
        NButton,
        {
          size: 'small',
          type: 'warning',
          onClick: () => quickOpenShort(row.coin)
        },
        { default: () => '快速开空' }
      ),
      h(
        NButton,
        {
          size: 'small',
          type: 'error',
          onClick: () => deleteCoin(row.coin)
        },
        { default: () => '删除' }
      )
    ])
  }
}

// 币种列定义
const coinColumn = {
  title: '币种',
  key: 'coin',
  fixed: 'left',
  width: CELL_WIDTH * 1.5, // 105px
  sorter: (rowA, rowB) => {
    const percentA = typeof rowA._changePercent === 'number' && isFinite(rowA._changePercent) ? rowA._changePercent : 0
    const percentB = typeof rowB._changePercent === 'number' && isFinite(rowB._changePercent) ? rowB._changePercent : 0
    return percentB - percentA // 降序排列，涨幅大的在前
  },
  render: (row) => {
    const pct = typeof row._changePercent === 'number' && isFinite(row._changePercent)
      ? row._changePercent
      : null
    
    const changePercentElement = pct !== null ? (() => {
      const abs = Math.abs(pct)
      const zeroish = abs < 0.0001
      const color = zeroish ? '#000' : (pct > 0 ? '#16a34a' : '#dc2626')
      const text = `${zeroish ? '0.0' : pct.toFixed(1)}%`
      return h('span', { 
        style: `margin-left: 8px; color: ${color}; font-size: 12px; white-space: nowrap; line-height: 1.2;` 
      }, text)
    })() : null
    
    const firstCaptureElement = row._firstCapture ? h('div', { class: 'first-label' }, [
      h('div', null, row._firstCapture.time),
      h('div', null, row._firstCapture.value)
    ]) : null
    
    return h('div', { class: 'coin-cell' }, [
      h('div', { class: 'coin-name-line' }, [
        h('span', { class: 'coin-name' }, row.coin),
        changePercentElement
      ]),
      firstCaptureElement
    ])
  }
}

// 选择列定义
const selectionColumn = {
  type: 'selection',
  width: 50,
  fixed: 'left',
  title: '',
  resizable: false
}

// 列定义
const columns = ref([
  selectionColumn,
  coinColumn,
  thresholdsColumn,
  actionColumn
])

// 计算横向滚动宽度（缓存计算结果）
const scrollX = ref(600)
const updateScrollX = () => {
  const base = columns.value.reduce((sum, col) => sum + (Number(col.width) || CELL_WIDTH), 0)
  scrollX.value = Math.max(base, 600)
}

// 响应式引用
const tableWrapperRef = ref(null)
const dataTableRef = ref(null)

// 选择事件处理
function onCheckedRowKeysChange(keys) {
  console.log('CoinTable 选择键变化:', keys)
  selectedRowKeys.value = keys
  const selectedRows = keys.map(key => tableData.find(row => row.coin === key)).filter(Boolean)
  console.log('CoinTable 选中的行数据:', selectedRows)
  emit('row-selection', selectedRows)
}

// 获取表格数据的方法
function getTableData() {
  return tableData.map(row => ({
    ...row,
    _timeColumns: timeColumns.value
  }))
}

// 导出选中数据
function exportSelectedData() {
  if (selectedRowKeys.value.length === 0) {
    console.warn('没有选中任何数据')
    return
  }
  
  console.log('开始导出选中数据:', selectedRowKeys.value)
  console.log('当前表格数据:', tableData)
  console.log('时间列配置:', timeColumns.value)
  
  // 获取选中的行数据
  const selectedRows = selectedRowKeys.value.map(key => 
    tableData.find(row => row.coin === key)
  ).filter(Boolean)
  
  console.log('选中的行数据:', selectedRows)
  
  if (selectedRows.length === 0) {
    console.warn('没有找到选中的数据')
    return
  }
  
  // 转换数据格式
  const exportData = convertToExcelFormat(selectedRows)
  console.log('转换后的导出数据:', exportData)
  
  // 生成文件名
  const tableType = props.apiPrefix === '/admin' ? '管理员' : '普通用户'
  const dateStr = new Date().toISOString().slice(0, 10)
  const filename = `${tableType}数据_${dateStr}`
  
  // 下载文件
  downloadExcel(exportData, filename)
}

// 转换数据为Excel格式
function convertToExcelFormat(rows) {
  if (rows.length === 0) return []
  
  console.log('开始转换数据，输入行数:', rows.length)
  console.log('时间列:', timeColumns.value)
  console.log('第一行数据示例:', rows[0])
  console.log('第一行数据的所有键:', Object.keys(rows[0] || {}))
  console.log('第一行数据的_rawByTime:', rows[0]?._rawByTime)
  
  // 检查是否有数据
  if (rows.length > 0) {
    console.log('检查第一行的时间列数据:')
    timeColumns.value.forEach(col => {
      const timestamp = col.key
      console.log(`  ${timestamp}: row[${timestamp}] = ${rows[0][timestamp]}, _rawByTime[${timestamp}] = ${rows[0]._rawByTime?.[timestamp]}`)
    })
  }
  
  // 创建表头（时间列标题去掉前缀 K 以便阅读）
  const headers = ['币种']
  
  // 添加时间列头
  if (timeColumns.value && timeColumns.value.length > 0) {
    timeColumns.value.forEach((timestamp) => {
      const title = typeof timestamp === 'string' ? timestamp.replace(/^K/, '') : String(timestamp)
      headers.push(title)
    })
  }
  
  console.log('表头:', headers)
  
  const data = [headers]
  
  // 添加数据行
  rows.forEach((row, index) => {
    console.log(`处理第${index + 1}行:`, row)
    const rowData = [row.coin]
    
    // 添加时间数据（timeColumns 为字符串时间键，如 'K21:41:04'）
    if (timeColumns.value && timeColumns.value.length > 0) {
      timeColumns.value.forEach((timestamp) => {
        const key = typeof timestamp === 'string' ? timestamp : String(timestamp)
        console.log(`处理时间列 ${key}:`)
        console.log(`  row[${key}]:`, row[key])
        console.log(`  row._rawByTime[${key}]:`, row._rawByTime?.[key])
        
        // 使用显示值（带汉字的格式），然后只提取数字部分
        const displayValue = row[key]
        console.log(`  显示值: ${displayValue}`)
        
        if (displayValue !== undefined && displayValue !== null && displayValue !== '0') {
          // 只去掉汉字，保留数字和小数点
          const cleanValue = String(displayValue).replace(/[^\d.-]/g, '')
          const numValue = parseFloat(cleanValue)
          console.log(`  清理后的值: ${cleanValue} -> 数字: ${numValue}`)
          rowData.push(isNaN(numValue) ? 0 : numValue)
        } else {
          console.log(`  值为空或0，添加0`)
          rowData.push(0)
        }
      })
    }
    
    console.log(`第${index + 1}行数据:`, rowData)
    data.push(rowData)
  })
  
  console.log('最终导出数据:', data)
  return data
}

// 下载Excel文件
function downloadExcel(data, filename) {
  if (data.length === 0) {
    console.warn('没有数据可导出')
    return
  }
  
  try {
    const wb = XLSX.utils.book_new()
    const ws = XLSX.utils.aoa_to_sheet(data)
    
    // 设置列宽
    const colWidths = data[0].map((_, index) => {
      if (index === 0) return { wch: 10 } // 币种列
      if (index === 1) return { wch: 12 } // 涨跌幅列
      return { wch: 15 } // 其他列
    })
    ws['!cols'] = colWidths
    
    XLSX.utils.book_append_sheet(wb, ws, '数据')
    
    const fileName = `${filename}.xlsx`
    XLSX.writeFile(wb, fileName)
    console.log('文件导出成功:', fileName)
  } catch (error) {
    console.error('导出失败:', error)
  }
}

// 导出今日全部数据
async function exportTodayAllData() {
  try {
    console.log('开始导出今日全部数据...')
    
    // 构建请求 URL
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/export/excel` :
      `${import.meta.env.VITE_API_BASE}/pool/export/excel`
    
    console.log('请求 URL:', endpoint)
    
    // 发送 GET 请求下载文件
    const response = await axios.get(endpoint, {
      responseType: 'blob' // 重要：指定响应类型为 blob
    })
    
    // 创建下载链接
    const blob = new Blob([response.data], { 
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' 
    })
    const url = window.URL.createObjectURL(blob)
    
    // 创建下载链接并触发下载
    const link = document.createElement('a')
    link.href = url
    
    // 生成文件名
    const tableType = props.apiPrefix === '/admin' ? '管理员' : '普通用户'
    const dateStr = new Date().toISOString().slice(0, 10)
    const filename = `${tableType}今日数据_${dateStr}.xlsx`
    
    link.download = filename
    document.body.appendChild(link)
    link.click()
    
    // 清理
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    
    console.log('文件下载成功:', filename)
  } catch (error) {
    console.error('导出今日全部数据失败:', error)
    // 可以添加用户提示
  }
}

// 暴露给父组件的方法
defineExpose({
  refreshTable,
  addCoin,
  getTableData,
  deleteCoin,
  scrollToRightMost
})

// 初始化
onMounted(async () => {
  // 获取支持的币种列表
  supportedCoins.value = await getAllSupportedCoins()
  
  // 获取服务器币列表并初始化表格
  const serverCoins = await fetchPoolCoins()
  await rebuildTableForCoins(serverCoins)
  await restoreHistoricalData() // 恢复历史数据
  
  // 启动定时器
  setInterval(refreshTable, 15 * 1000) // 每5秒刷新数据（降低频率）
  setInterval(checkServerCoinsSync, 30 * 1000) // 每30秒检查币列表同步（降低频率）
  
  // 首次刷新
  await refreshTable()
  await scrollToRightMost()
})
</script>

<style scoped>
.controls-row {
  display: flex;
  align-items: center;
  margin-bottom: 16px;
  gap: 16px;
}

.color-legend {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
  padding: 8px 12px;
  background-color: #f8f9fa;
  border-radius: 6px;
  font-size: 12px;
  color: #666;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.color-box {
  width: 12px;
  height: 12px;
  border-radius: 2px;
  border: 1px solid #ddd;
}

.table-wrapper {
  width: 100%;
  overflow-x: auto;
}

.coin-name {
  font-weight: 700;
  font-size: 16px;
  flex-shrink: 0;
}

.coin-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  max-width: 100px;
}

.coin-name-line {
  display: flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
  overflow: hidden;
}

.first-label {
  font-size: 11px;
  color: #666;
  line-height: 1.2;
}

/* 压缩 DataTable 单元格内边距与字号 */
:deep(.n-data-table) {
  --n-td-padding: 2px 4px;
  --n-th-padding: 2px 4px;
  --n-td-text-color: inherit;
  --n-th-text-color: inherit;
}

:deep(.n-data-table .n-data-table-td),
:deep(.n-data-table .n-data-table-th) {
  padding: 2px 4px !important;
  font-size: 12px;
}

/* 阈值输入框样式 */
:deep(.n-input-number .n-input) {
  font-size: 10px;
  padding: 2px 4px;
}

/* 隐藏输入框的+-按钮 */
:deep(.n-input-number .n-input-number-suffix) {
  display: none !important;
}

/* 固定列样式 */
:deep(.n-data-table .n-data-table-th[data-col-key="selection"]) {
  position: sticky !important;
  left: 0 !important;
  z-index: 10 !important;
  background: var(--n-th-color) !important;
}

:deep(.n-data-table .n-data-table-td[data-col-key="selection"]) {
  position: sticky !important;
  left: 0 !important;
  z-index: 10 !important;
  background: var(--n-td-color) !important;
}

:deep(.n-input-number .n-input-number-prefix) {
  display: none !important;
}
</style>
