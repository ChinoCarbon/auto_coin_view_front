<template>
  <div>
    <n-auto-complete 
      v-model:value="inputValue" 
      :options="autoCompleteOptions" 
      placeholder="请输入币种名称" 
      @keyup.enter="onSearch" 
    /> 
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
import { NButton, NTooltip, NInputNumber } from 'naive-ui'
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
const CELL_WIDTH = 70

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
    console.error(err)
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

// 获取币种位置信息
async function getCoinPosition(coin) {
  try {
    const endpoint = props.apiPrefix ? 
      `${import.meta.env.VITE_API_BASE}${props.apiPrefix}/single_coin_interest_info/${coin}` :
      `${import.meta.env.VITE_API_BASE}/single_coin_interest_info/${coin}`
    
    const res = await axios.get(endpoint)
    const data = res.data
    if (data && data.value !== undefined && data.timestamp) {
      return {
        value: Number(data.value) || 0,
        timestamp: data.timestamp,
        dataCount: data.data_count || 0,
        isMonitored: data.is_monitored || false
      }
    }
    return { value: 0, timestamp: null, dataCount: 0, isMonitored: false }
  } catch (err) {
    console.error(err)
    return { value: 0, timestamp: null, dataCount: 0, isMonitored: false }
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
    console.error(err)
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
    console.error(err)
    return []
  }
}

// 恢复所有币的历史数据并重建时间列
async function restoreHistoricalData() {
  console.log('restoreHistoricalData called, tableData length:', tableData.length)
  const allTimePoints = new Set()
  
  // 为每个币获取历史数据
  for (const row of tableData) {
    console.log('Processing coin:', row.coin)
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
      console.warn(`Failed to fetch historical data for ${row.coin}:`, err.message)
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
      render: (row) =>
        h(
          NTooltip,
          { placement: 'top' },
          {
            trigger: () => h('span', null, row[time] || '0'),
            default: () => formatWithSeparators(row._rawByTime && row._rawByTime[time])
          }
        )
    })
  })
  
  // 添加操作列
  newColumns.push(actionColumn)
  columns.value = newColumns
}

// 重建表格
async function rebuildTableForCoins(newCoins) {
  internalCoins.value = newCoins
  
  // 重建表格数据
  const newTableData = []
  for (const coin of internalCoins.value) {
    const row = { coin, _rawByTime: {} }
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
  // 并发请求所有币（返回新格式数据）
  const results = await Promise.all(internalCoins.value.map(getCoinPosition))

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
      if (row._firstCapture) {
        const baseline = typeof row._firstCapture.baseline === 'number' && isFinite(row._firstCapture.baseline)
          ? row._firstCapture.baseline
          : parseDisplayToNumber(row._firstCapture.value)
        const current = raw
        if (isFinite(baseline) && baseline !== 0 && isFinite(current)) {
          row._changePercent = ((current - baseline) / baseline) * 100
        } else {
          row._changePercent = undefined
        }
      }
    }
  })
  
  // 如果有新币种第一次有数据，触发重新加载
  if (needsReload) {
    console.log('检测到新币种第一次有数据，触发重新加载')
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
      render: (row) =>
        h(
          NTooltip,
          { placement: 'top' },
          {
            trigger: () => h('span', null, row[timestamp] || '0'),
            default: () => formatWithSeparators(row._rawByTime && row._rawByTime[timestamp])
          }
        )
    };
    const last = columns.value[columns.value.length - 1];
    if (last && last.key === 'actions') {
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
      console.log('币列表有变化，同步更新')
      
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
          const newRow = { coin, _rawByTime: {} }
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
    console.error('检查币列表同步失败:', err)
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
        const newRow = { coin: value, _rawByTime: {} }
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
      console.error(err)
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
      console.error(err)
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
  console.log('CoinTable mounted')
  
  // 获取支持的币种列表
  supportedCoins.value = await getAllSupportedCoins()
  console.log('supportedCoins:', supportedCoins.value)
  
  // 获取服务器币列表并初始化表格
  const serverCoins = await fetchPoolCoins()
  console.log('serverCoins:', serverCoins)
  await rebuildTableForCoins(serverCoins)
  console.log('After rebuildTableForCoins, tableData:', tableData)
  await restoreHistoricalData() // 恢复历史数据
  console.log('After restoreHistoricalData, tableData:', tableData)
  
  // 启动定时器
  setInterval(refreshTable, 10 * 1000) // 每10秒刷新数据（降低频率）
  setInterval(checkServerCoinsSync, 30 * 1000) // 每30秒检查币列表同步（降低频率）
  
  // 首次刷新
  await refreshTable()
  await scrollToRightMost()
})
</script>

<style scoped>
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
</style>
