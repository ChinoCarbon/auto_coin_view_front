<template>
  <n-layout>
    <n-layout-header style="display: flex; justify-content: center;">
      <h2 style="color: black; padding: 0 16px;">动态表格 V2.0</h2>
    </n-layout-header>
    <n-layout-content style="padding: 16px">
      <n-auto-complete v-model:value="inputValue" :options="autoCompleteOptions" placeholder="请输入币种名称" @keyup.enter="onSearch" /> 
      <!-- <n-card> -->
        <div class="table-wrapper" ref="tableWrapperRef">
          <n-data-table ref="dataTableRef" :columns="columns" :data="tableData" :scroll-x="scrollX" size="small" bordered striped />
        </div>
      <!-- </n-card> -->
    </n-layout-content>
  </n-layout>
</template>

<script setup>
import { ref, reactive, onMounted, computed, h, nextTick } from 'vue'
import axios from 'axios'
import { NButton, NTooltip } from 'naive-ui'
const coins = ref([])

// 初始化表格数据，每行包含币种和一个默认列
function getSecondLabel() {
  const now = new Date()
  const hh = String(now.getHours()).padStart(2, '0')
  const mm = String(now.getMinutes()).padStart(2, '0')
  const ss = String(now.getSeconds()).padStart(2, '0')
  return `${hh}:${mm}:${ss}`
}
const initialTime = getSecondLabel()
const CELL_WIDTH = 70
const tableData = reactive(coins.value.map(coin => ({ coin, [initialTime]: 0 })))
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
const columns = ref([
  {
    title: '币种',
    key: 'coin',
    fixed: 'left',
    width: 100,
    render: (row) => {
      const pct = typeof row._changePercent === 'number' && isFinite(row._changePercent)
        ? row._changePercent
        : null
      
      const changePercentElement = pct !== null ? (() => {
        const abs = Math.abs(pct)
        const zeroish = abs < 0.0001
        const color = zeroish ? '#000' : (pct > 0 ? '#16a34a' : '#dc2626')
        const text = `${zeroish ? '0.0' : pct.toFixed(1)}%`
        return h('span', { style: `margin-left: 8px; color: ${color};` }, text)
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
  },
  actionColumn
])
const timeColumns = ref([initialTime])
const supportedCoins = ref([])
const inputValue = ref('')
const tableWrapperRef = ref(null)
const dataTableRef = ref(null)

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

// 根据列宽动态计算横向滚动宽度
const scrollX = computed(() => {
  const base = columns.value.reduce((sum, col) => sum + (Number(col.width) || CELL_WIDTH), 0)
  return Math.max(base, 600)
})

// 获取持仓量（返回原始数值，显示时再格式化）
async function getCoinPosition(coin) {
  try {
    const res = await axios.get(`${import.meta.env.VITE_API_BASE}/single_coin_interest_info/${coin}`)
    console.log(res.data)
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

// 刷新表格
async function refreshTable() {
  // 并发请求所有币（返回新格式数据）
  const results = await Promise.all(coins.value.map(getCoinPosition))

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
  const sortedNewTimestamps = Array.from(newTimestamps).sort()
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
    }
    const last = columns.value[columns.value.length - 1]
    if (last && last.key === 'actions') {
      columns.value.splice(columns.value.length - 1, 0, newCol)
    } else {
      columns.value.push(newCol)
    }
    timeColumns.value.push(timestamp)
  })
  
  // 如果有新列，滚动到最右侧
  if (sortedNewTimestamps.length > 0) {
    await scrollToRightMost()
  }
}

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

// 从后端池获取当前币列表
async function fetchPoolCoins() {
  try {
    const res = await axios.get(`${import.meta.env.VITE_API_BASE}/pool/coins`)
    const list = Array.isArray(res.data && res.data.coins) ? res.data.coins : []
    return list.map((c) => String(c))
  } catch (err) {
    console.error(err)
    return []
  }
}

// 获取币的历史信息（起始时间和初始价格）
async function fetchCoinInfo(coin) {
  try {
    const res = await axios.get(`${import.meta.env.VITE_API_BASE}/pool/data/${coin}`)
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
    
    // 获取完整的历史数据系列
    try {
      const res = await axios.get(`${import.meta.env.VITE_API_BASE}/pool/data/${row.coin}`)
      const data = res.data
      console.log('Historical data for', row.coin, ':', data)
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
      console.error(`Failed to fetch data for ${row.coin}:`, err)
    }
  }
  
  // 重建时间列（按时间顺序）
  const sortedTimes = Array.from(allTimePoints).sort()
  timeColumns.value = sortedTimes
  
  // 重建列定义
  const newColumns = [
    {
      title: '币种',
      key: 'coin',
      fixed: 'left',
      width: 100,
      render: (row) => {
        const pct = typeof row._changePercent === 'number' && isFinite(row._changePercent)
          ? row._changePercent
          : null
        
        const changePercentElement = pct !== null ? (() => {
          const abs = Math.abs(pct)
          const zeroish = abs < 0.0001
          const color = zeroish ? '#000' : (pct > 0 ? '#16a34a' : '#dc2626')
          const text = `${zeroish ? '0.0' : pct.toFixed(1)}%`
          return h('span', { style: `margin-left: 8px; color: ${color};` }, text)
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

async function rebuildTableForCoins(newCoins) {
  coins.value = newCoins
  
  // 重建表格数据
  const newTableData = []
  for (const coin of coins.value) {
    const row = { coin, _rawByTime: {} }
    newTableData.push(row)
  }
  tableData.splice(0, tableData.length, ...newTableData)
}

function onSearch() {
  const value = (inputValue.value || '').trim()
  if (!value) return
  // 如果提供了支持列表，则只在支持列表内搜索
  if (supportedCoins.value.length > 0 && !supportedCoins.value.includes(value)) {
    return
  }
  // 改为后端添加：成功后只添加新行，等待第一次数据更新
  axios.post(`${import.meta.env.VITE_API_BASE}/pool/coins`, { coin: value })
    .then(async () => {
      // 只添加新币到现有表格，保持历史数据
      if (!coins.value.includes(value)) {
        coins.value.push(value)
        const newRow = { coin: value, _rawByTime: {} }
        // 为已有时间列初始化为 0
        timeColumns.value.forEach((t) => {
          newRow[t] = '0'
          newRow._rawByTime[t] = 0
        })
        tableData.push(newRow)
        
        // 标记为需要重新加载的币种
        newRow._needsReload = true
      }
      inputValue.value = ''
      await refreshTable()
    })
    .catch((err) => console.error(err))
}

function deleteCoin(coin) {
  // 改为后端删除：成功后只删除对应行，保持其他历史数据
  axios.delete(`${import.meta.env.VITE_API_BASE}/pool/coins/${coin}`)
    .then(async () => {
      // 只删除对应币种，保持其他历史数据
      const idx = coins.value.indexOf(coin)
      if (idx !== -1) coins.value.splice(idx, 1)
      const rowIdx = tableData.findIndex((r) => r.coin === coin)
      if (rowIdx !== -1) tableData.splice(rowIdx, 1)
      await refreshTable()
    })
    .catch((err) => console.error(err))
}

// 检查服务器币列表是否有变化
async function checkServerCoinsSync() {
  try {
    const serverCoins = await fetchPoolCoins()
    const currentCoins = coins.value.map(c => String(c)).sort()
    const serverCoinsSorted = serverCoins.sort()
    
    // 比较币列表是否有变化
    if (JSON.stringify(currentCoins) !== JSON.stringify(serverCoinsSorted)) {
      console.log('币列表有变化，同步更新')
      
      // 找出新增和删除的币种
      const addedCoins = serverCoins.filter(coin => !coins.value.includes(coin))
      const removedCoins = coins.value.filter(coin => !serverCoins.includes(coin))
      
      // 删除被移除的币种
      removedCoins.forEach(coin => {
        const idx = coins.value.indexOf(coin)
        if (idx !== -1) coins.value.splice(idx, 1)
        const rowIdx = tableData.findIndex((r) => r.coin === coin)
        if (rowIdx !== -1) tableData.splice(rowIdx, 1)
      })
      
      // 添加新币种
      for (const coin of addedCoins) {
        if (!coins.value.includes(coin)) {
          coins.value.push(coin)
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
        }
      }
    }
  } catch (err) {
    console.error('检查币列表同步失败:', err)
  }
}

// 页面挂载后启动定时器
onMounted(async () => {
    console.log('onMounted started')
    supportedCoins.value = await getAllSupportedCoins()
    console.log('supportedCoins:', supportedCoins.value)
    const serverCoins = await fetchPoolCoins()
    console.log('serverCoins:', serverCoins)
    await rebuildTableForCoins(serverCoins)
    console.log('After rebuildTableForCoins, tableData:', tableData)
    await restoreHistoricalData() // 恢复历史数据
    console.log('After restoreHistoricalData, tableData:', tableData)
    await refreshTable() // 初始化拉一次真实数据
    console.log('After refreshTable, tableData:', tableData)
    // 首次进入也滚到最右侧
    await scrollToRightMost()
    
    // 启动定时器
    setInterval(refreshTable, 5 * 1000) // 每5秒刷新数据
    setInterval(checkServerCoinsSync, 10 * 1000) // 每10秒检查币列表同步
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
}
.coin-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.coin-name-line {
  display: flex;
  align-items: center;
  gap: 8px;
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
