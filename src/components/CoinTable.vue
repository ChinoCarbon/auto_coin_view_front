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
      />
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, h, nextTick, watch, onMounted } from 'vue'
import { NButton, NTooltip, NInputNumber, NSwitch, useNotification } from 'naive-ui'
import axios from 'axios'

// Props
const props = defineProps({
  apiPrefix: {
    type: String,
    default: '' // 空字符串表示普通接口，'/admin' 表示管理员接口
  }
})

// Emits
const emit = defineEmits([
  'coin-added',
  'coin-deleted',
  'table-refreshed'
])

// 内部状态
const internalCoins = ref([])
const tableData = reactive([])
const timeColumns = ref([])
const supportedCoins = ref([])
const inputValue = ref('')
const soundEnabled = ref(true) // 提示音开关，默认开启
const CELL_WIDTH = 70

// 通知实例
const notification = useNotification()

// 存储已触发的警告，避免重复触发
const triggeredWarnings = ref(new Set())

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
        return `${(value / 1e8).toFixed(1)}亿`
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
  
  // 根据类型选择不同的通知样式
  const isRiseAlert = type === '拉升'
  const notificationConfig = {
    title: isRiseAlert ? '快速拉升提醒' : '持仓量下降预警',
    content: `${coin}的${type}为${formattedActual}，超过阈值${formattedThreshold}。数据出现时间：${timestamp}`,
    duration: 0, // 不自动关闭
    closable: true,
    onClose: () => {
      // 警告关闭时从已触发列表中移除，但使用更持久的key
      // 使用币种+类型作为key，避免同一币种的同一类型警告重复出现
      const persistentKey = `${coin}-${type}`
      triggeredWarnings.value.add(persistentKey)
    }
  }
  
  if (isRiseAlert) {
    notification.info(notificationConfig)
  } else {
    notification.error(notificationConfig)
  }
  
  // 播放警告声音
  playAlertSound()
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

// 实际播放声音的函数
function playSound(audioContext) {
  try {
    const oscillator = audioContext.createOscillator()
    const gainNode = audioContext.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    // 创建更明显的提示音：三声短促的"哔"声
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
    return (num / 1e8).toFixed(1) + '亿'
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
    if (data && data.series && Array.isArray(data.series) && data.series.length > 0) {
      // 取第一个数据点作为起始时间和价格
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

// 从后端池获取当前币列表
async function fetchPoolCoins() {
  try {
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/pool/coins` :
      `${import.meta.env.VITE_API_BASE}/pool/coins`
    
    const res = await axios.get(endpoint)
    const list = Array.isArray(res.data && res.data.coins) ? res.data.coins : []
    return list.map((c) => String(c))
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
  
  // 重建列定义
  const newColumns = [
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
      title: time,
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

// 刷新表格
async function refreshTable() {
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
    }
  })
  
  // 如果有新币种第一次有数据，触发重新加载
  if (needsReload) {
    const serverCoins = await fetchPoolCoins()
    await rebuildTableForCoins(serverCoins)
    await restoreHistoricalData()
    return // 重新加载后直接返回，不继续执行后续逻辑
  }

  // 添加新时间戳列（去重后）
  const sortedNewTimestamps = Array.from(newTimestamps).sort();
  sortedNewTimestamps.forEach(timestamp => {
    const newCol = {
      title: timestamp,
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
}

// 检查服务器币列表是否有变化
async function checkServerCoinsSync() {
  try {
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
          
          // 尝试获取新币的历史信息
          const coinInfo = await fetchCoinInfo(coin)
          if (coinInfo) {
            newRow._firstCapture = coinInfo
          }
          
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
  width: CELL_WIDTH,
  render: (row) =>
    h(
      NButton,
      {
        size: 'small',
        type: 'error',
        onClick: () => deleteCoin(row.coin)
      },
      { default: () => '删除' }
    )
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

// 列定义
const columns = ref([
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

// 暴露给父组件的方法
defineExpose({
  refreshTable,
  addCoin,
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
  setInterval(refreshTable, 5 * 1000) // 每5秒刷新数据（降低频率）
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

:deep(.n-input-number .n-input-number-prefix) {
  display: none !important;
}
</style>
