<template>
  <div class="user-management">
    <!-- 操作按钮 -->
    <div class="action-buttons">
      <n-button 
        type="primary" 
        :loading="positionsLoading"
        @click="fetchAllPositions"
      >
        刷新仓位
      </n-button>
      
      <n-button 
        type="default" 
        :loading="loading"
        @click="forceRefresh"
      >
        强制刷新全部
      </n-button>
      
      <n-button 
        type="success" 
        @click="openBatchOrderModal"
      >
        批量下单
      </n-button>
      
      <div class="auto-refresh-controls">
        <n-switch 
          v-model:value="autoRefresh" 
          @update:value="toggleAutoRefresh"
        />
        <span class="control-label">自动刷新仓位</span>
        
        <n-input-number 
          v-model:value="refreshRate" 
          :min="1000" 
          :max="30000" 
          :step="1000"
          :disabled="!autoRefresh"
          @update:value="updateRefreshRate"
        />
        <span class="control-label">毫秒</span>
        
        <span v-if="lastUpdateTime" class="last-update">
          最后更新: {{ formatTime(lastUpdateTime) }}
        </span>
      </div>
    </div>
    
    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      <n-empty description="正在加载用户数据..." />
    </div>
    
    <!-- 用户卡片网格 -->
    <div v-else-if="users.length > 0" class="user-cards-grid">
      <div 
        v-for="user in users" 
        :key="user.id"
        class="user-card"
        :class="{ 'expanded': expandedUsers.includes(user.id) }"
        @click="toggleUser(user.id)"
      >
        <!-- 卡片头部 -->
        <div class="card-header">
          <div class="user-info">
            <div class="user-avatar">
              <span>{{ user.name.charAt(0).toUpperCase() }}</span>
            </div>
            <div class="user-details">
              <h3 class="user-name">
                {{ user.name }}
                <span v-if="user.useTestnet" class="testnet-badge">测试网</span>
              </h3>
              <p class="user-balance">可用余额: ${{ user.availableBalance?.toFixed(2) || '0.00' }}</p>
              <p v-if="user.walletBalance" class="user-wallet-balance">钱包余额: ${{ user.walletBalance.toFixed(2) }}</p>
              <p v-if="user.unrealizedProfit !== undefined" class="user-unrealized-pnl" :class="user.unrealizedProfit >= 0 ? 'positive' : 'negative'">
                未实现盈亏: {{ user.unrealizedProfit >= 0 ? '+' : '' }}${{ user.unrealizedProfit.toFixed(2) }}
              </p>
              <p class="user-id">ID: {{ user.id.slice(0, 8) }}...</p>
              <p class="user-created">创建时间: {{ formatDate(user.createdAt) }}</p>
            </div>
          </div>
          <div class="user-status">
            <span class="status-badge" :class="user.status">
              {{ user.status === 'online' ? '在线' : '离线' }}
            </span>
          </div>
        </div>

        <!-- 卡片内容 - 展开时显示 -->
        <div v-if="expandedUsers.includes(user.id)" class="card-content" @click.stop>
          <n-tabs type="line" animated>
            <!-- 仓位情况 Tab -->
            <n-tab-pane name="positions" tab="仓位情况">
              <div class="tab-content">
                <div class="positions-header">
                  <h4>当前仓位</h4>
                  <n-button 
                    size="small" 
                    type="primary" 
                    :loading="positionsLoading"
                    @click="refreshPositions"
                  >
                    刷新仓位
                  </n-button>
                </div>
                
                <div class="positions-list">
                  <div v-if="user.positions && user.positions.length > 0">
                    <div 
                      v-for="position in user.positions" 
                      :key="position.id"
                      class="position-item"
                    >
                      <div class="position-info">
                        <span class="coin-name">{{ position.symbol }}</span>
                        <span class="position-side" :class="position.side.toLowerCase()">
                          {{ position.side === 'LONG' ? '多' : '空' }}
                        </span>
                        <span class="leverage-badge">{{ position.leverage.toFixed(1) }}x</span>
                      </div>
                      <div class="position-details">
                        <div class="price-info">
                          <span class="entry-price">入场价: ${{ position.entryPrice.toFixed(6) }}</span>
                          <span class="mark-price">标记价: ${{ position.markPrice.toFixed(6) }}</span>
                        </div>
            
                        <div class="pnl-info">
                          <span class="pnl-value" :class="position.unrealizedPnl >= 0 ? 'positive' : 'negative'">
                            {{ position.unrealizedPnl >= 0 ? '+' : '' }}${{ position.unrealizedPnl.toFixed(2) }}
                          </span>
                          <span class="pnl-percentage" :class="position.percentage >= 0 ? 'positive' : 'negative'">
                            {{ position.percentage >= 0 ? '+' : '' }}{{ position.percentage.toFixed(2) }}%
                          </span>
                        </div>
                        <div class="margin-info">
                            <span class="notional-label">持仓数量: ${{ position.notional.toFixed(6) }}</span>
                             <span class="margin-label">保证金: ${{ position.margin.toFixed(6) }}</span>
                        
                        </div>

                      </div>
                    </div>
                  </div>
                  <div v-else class="empty-state">
                    <n-empty description="暂无仓位数据" />
                  </div>
                </div>
              </div>
            </n-tab-pane>

            <!-- 挂单情况 Tab -->
            <n-tab-pane name="orders" tab="挂单情况">
              <div class="tab-content">
                <div class="orders-header">
                  <h4>当前挂单</h4>
                  <n-button 
                    size="small" 
                    type="primary" 
                    :loading="ordersLoading"
                    @click="refreshOrders"
                  >
                    刷新挂单
                  </n-button>
                </div>
                
                <div class="orders-list">
                  <div v-if="user.orders && user.orders.length > 0">
                    <div 
                      v-for="order in user.orders" 
                      :key="order.id"
                      class="order-item"
                    >
                      <div class="order-info">
                        <span class="order-side" :class="order.side.toLowerCase()">
                          {{ order.side === 'BUY' ? '买入' : '卖出' }}
                        </span>
                        <span class="coin-name">{{ order.symbol }}</span>
                        <span class="order-type">{{ getOrderTypeText(order.type) }}</span>
                      </div>
                      <div class="order-details">
                        <div class="price-qty-info">
                          <span class="order-price">价格: ${{ order.price.toFixed(6) }}</span>
                          <span class="order-qty">数量: {{ order.origQty.toFixed(6) }}</span>
                        </div>
                        <div v-if="order.stopPrice > 0" class="stop-price-info">
                          <span class="stop-price">止损价: ${{ order.stopPrice.toFixed(6) }}</span>
                        </div>
                        <div class="status-time-info">
                          <span class="order-status" :class="order.status.toLowerCase()">
                            {{ getOrderStatusText(order.status) }}
                          </span>
                          <span class="order-time">{{ formatOrderTime(order.time) }}</span>
                        </div>
                        <div class="execution-info">
                          <span class="executed-qty">已成交: {{ order.executedQty.toFixed(6) }}</span>
                          <span class="remaining-qty">剩余: {{ (order.origQty - order.executedQty).toFixed(6) }}</span>
                        </div>
                        <div v-if="order.reduceOnly || order.closePosition" class="order-flags">
                          <span v-if="order.reduceOnly" class="flag reduce-only">减仓</span>
                          <span v-if="order.closePosition" class="flag close-position">平仓</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div v-else class="empty-state">
                    <n-empty description="暂无挂单数据" />
                  </div>
                </div>
              </div>
            </n-tab-pane>
          </n-tabs>
        </div>
      </div>
    </div>
    
    <!-- 空状态 -->
    <div v-else class="empty-state">
      <n-empty description="暂无用户数据" />
    </div>
    
    <!-- 批量下单弹窗 -->
    <n-modal v-model:show="showBatchOrderModal" preset="dialog" title="批量下单" size="large">
      <n-form :model="batchOrderForm" label-placement="left" label-width="120px">
        <n-form-item label="选择用户">
          <n-checkbox-group v-model:value="selectedUsers">
            <n-checkbox 
              v-for="user in users" 
              :key="user.id" 
              :value="user.id"
            >
              <span>{{ user.alias }} (余额: ${{ user.availableBalance?.toFixed(2) || '0.00' }})</span>
            </n-checkbox>
          </n-checkbox-group>
        </n-form-item>
        
        <n-form-item label="交易对">
          <n-select 
            v-model:value="batchOrderForm.symbol" 
            placeholder="选择交易对"
            :options="availableSymbols"
            @update:value="onSymbolChange"
          />
        </n-form-item>
        
        <n-form-item v-if="batchOrderForm.symbol && symbolInfo.symbol" label="交易对信息">
          <div class="symbol-info">
            <div class="info-row">
              <span class="info-label">最大杠杆:</span>
              <span class="info-value">{{ symbolInfo.maxLeverage }}x</span>
            </div>
            <div class="info-row">
              <span class="info-label">最小下单量(币):</span>
              <span class="info-value">{{ symbolInfo.minQuantityByNotional }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">最小下单量(USDT):</span>
              <span class="info-value">${{ symbolInfo.minQuantityUSDT }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">价格精度:</span>
              <span class="info-value">{{ symbolInfo.tickSize }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">状态:</span>
              <span class="info-value" :class="symbolInfo.status === 'TRADING' ? 'status-trading' : 'status-other'">
                {{ symbolInfo.status === 'TRADING' ? '交易中' : symbolInfo.status }}
              </span>
            </div>
          </div>
        </n-form-item>
        
        <n-form-item label="交易方向">
          <n-radio-group v-model:value="batchOrderForm.side">
            <n-radio value="BUY">开多</n-radio>
            <n-radio value="SELL">开空</n-radio>
          </n-radio-group>
        </n-form-item>
        
        <n-form-item label="杠杆倍数">
          <n-input-number 
            v-model:value="batchOrderForm.leverage" 
            :min="1" 
            :max="maxLeverage"
            placeholder="输入杠杆倍数"
          />
          <span class="form-tip">范围: 1x - {{ maxLeverage }}x</span>
        </n-form-item>
        
        <n-form-item label="仓位百分比">
          <n-input-number 
            v-model:value="batchOrderForm.percentage" 
            :min="1" 
            :max="100"
            placeholder="占全仓百分比"
          />
          <span class="form-tip">%</span>
        </n-form-item>
        
        <n-alert type="info" style="margin-bottom: 16px;">
          实际持仓量 = 全仓资金 × 仓位百分比 × 杠杆倍数
        </n-alert>
        
        <n-form-item v-if="selectedUsers.length > 0" label="下单预览">
          <div class="order-preview">
            <div 
              v-for="userId in selectedUsers" 
              :key="userId"
              class="preview-item"
            >
              <span class="user-name">{{ users.find(u => u.id === userId)?.alias }}</span>
              <span class="amount">
                ${{ ((users.find(u => u.id === userId)?.availableBalance || 0) * batchOrderForm.percentage / 100).toFixed(2) }}
              </span>
            </div>
          </div>
        </n-form-item>
        
        <n-divider>止盈止损设置</n-divider>
        
        <n-form-item label="止盈价格">
          <n-input-number 
            v-model:value="batchOrderForm.takeProfitPrice" 
            :min="0"
            placeholder="止盈价格（可选）"
            clearable
          />
        </n-form-item>
        
        <n-form-item label="止损价格">
          <n-input-number 
            v-model:value="batchOrderForm.stopLossPrice" 
            :min="0"
            placeholder="止损价格（可选）"
            clearable
          />
        </n-form-item>
      </n-form>
      
      <template #action>
        <n-button @click="showBatchOrderModal = false">取消</n-button>
        <n-button 
          type="primary" 
          :loading="batchOrderLoading"
          @click="submitBatchOrder"
        >
          确认下单
        </n-button>
      </template>
    </n-modal>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { NTabs, NTabPane, NButton, NEmpty, NSwitch, NInputNumber, NModal, NForm, NFormItem, NSelect, NInput, NRadioGroup, NRadio, NCard, NCheckbox, NCheckboxGroup, NDivider, NAlert } from 'naive-ui'
import axios from 'axios'

// 响应式数据
const expandedUsers = ref([])
const users = ref([])
const loading = ref(false)
const positionsLoading = ref(false)
const ordersLoading = ref(false)
const autoRefresh = ref(true)
const refreshInterval = ref(null)
const refreshRate = ref(3000) // 3秒刷新一次
const lastUpdateTime = ref(null)

// 批量下单相关
const showBatchOrderModal = ref(false)
const batchOrderLoading = ref(false)
const selectedUsers = ref([])
const batchOrderForm = ref({
  symbol: '',
  side: 'BUY',
  leverage: 1,
  percentage: 10,
  takeProfitPrice: null,
  stopLossPrice: null
})
const availableSymbols = ref([])
const symbolInfo = ref({})
const maxLeverage = ref(1)
const minQuantityByNotional = ref(0.001)
const minQuantityUSDT = ref(10)
const tickSize = ref(0.1)

// 获取用户列表
async function fetchUsers() {
  try {
    loading.value = true
    console.log('开始获取用户列表...')
    
    const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/users`)
    console.log('用户列表响应:', response.data)
    
    if (response.data && response.data.success && response.data.data && Array.isArray(response.data.data.users)) {
      // 显示所有用户（包括测试网用户）
      const allUsers = response.data.data.users
      
      // 转换数据格式
      users.value = allUsers.map((user, index) => ({
        id: user.id,
        name: user.alias,
        alias: user.alias,
        isActive: user.is_active,
        createdAt: user.created_at,
        useTestnet: user.use_testnet,
        status: user.is_active ? 'online' : 'offline',
        positions: [], // 初始化为空，后续可以单独加载
        orders: [] // 初始化为空，后续可以单独加载
      }))
      
      console.log('处理后的用户数据:', users.value)
      console.log(`共获取到 ${users.value.length} 个用户`)
    } else {
      console.warn('用户数据格式不正确:', response.data)
      users.value = []
    }
  } catch (error) {
    console.error('获取用户列表失败:', error)
    users.value = []
  } finally {
    loading.value = false
  }
}

// 方法
function toggleUser(userId) {
  const index = expandedUsers.value.indexOf(userId)
  if (index > -1) {
    // 如果已展开，则折叠
    expandedUsers.value.splice(index, 1)
  } else {
    // 如果未展开，则展开
    expandedUsers.value.push(userId)
  }
}

function getOrderStatusText(status) {
  const statusMap = {
    'NEW': '新订单',
    'PARTIALLY_FILLED': '部分成交',
    'FILLED': '已成交',
    'CANCELED': '已取消',
    'PENDING_CANCEL': '取消中',
    'REJECTED': '已拒绝',
    'EXPIRED': '已过期'
  }
  return statusMap[status] || status
}

function getOrderTypeText(type) {
  const typeMap = {
    'LIMIT': '限价单',
    'MARKET': '市价单',
    'STOP_MARKET': '止损市价',
    'TAKE_PROFIT_MARKET': '止盈市价',
    'STOP_LOSS_LIMIT': '止损限价',
    'TAKE_PROFIT_LIMIT': '止盈限价'
  }
  return typeMap[type] || type
}

// 格式化挂单时间
function formatOrderTime(timestamp) {
  if (!timestamp) return '未知'
  try {
    const date = new Date(timestamp)
    return date.toLocaleString('zh-CN', {
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  } catch (error) {
    return '格式错误'
  }
}

// 格式化日期
function formatDate(dateString) {
  if (!dateString) return '未知'
  try {
    const date = new Date(dateString)
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    })
  } catch (error) {
    return '格式错误'
  }
}

// 格式化时间
function formatTime(date) {
  if (!date) return ''
  try {
    return date.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  } catch (error) {
    return '格式错误'
  }
}

// 获取所有用户的仓位数据
async function fetchAllPositions() {
  try {
    positionsLoading.value = true
    
    const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/positions/all`)
    
    if (response.data && response.data.success && response.data.data && Array.isArray(response.data.data.users)) {
      // 处理每个用户的仓位数据
      response.data.data.users.forEach(userData => {
        // 找到对应用户
        const user = users.value.find(u => u.alias === userData.alias)
        
        if (user && userData.positions && userData.positions.length > 0) {
          // 查找USDT钱包资产
          const walletAsset = userData.positions.find(pos => pos.type === 'wallet' && pos.asset === 'USDT')
          if (walletAsset) {
            user.availableBalance = parseFloat(walletAsset.availableBalance) || 0
            user.walletBalance = parseFloat(walletAsset.walletBalance) || 0
            user.marginBalance = parseFloat(walletAsset.marginBalance) || 0
            user.unrealizedProfit = parseFloat(walletAsset.unrealizedProfit) || 0
            user.crossUnPnl = parseFloat(walletAsset.crossUnPnl) || 0
            user.initialMargin = parseFloat(walletAsset.initialMargin) || 0
            user.maintMargin = parseFloat(walletAsset.maintMargin) || 0
            
            console.log(`用户 ${user.alias} USDT钱包信息:`, {
              availableBalance: walletAsset.availableBalance,
              walletBalance: walletAsset.walletBalance,
              marginBalance: walletAsset.marginBalance,
              unrealizedProfit: walletAsset.unrealizedProfit,
              crossUnPnl: walletAsset.crossUnPnl
            })
          } else {
            console.log(`用户 ${user.alias} 未找到USDT钱包资产，positions数量:`, userData.positions.length)
          }
          
          // 过滤出合约仓位（type === 'contract'）
          const contractPositions = userData.positions.filter(pos => pos.type === 'contract')
          
          // 转换仓位数据格式
          const newPositions = contractPositions.map(position => {
            // 使用新的字段结构
            const unrealizedPnl = parseFloat(position.unrealizedProfit) || 0
            const notional = Math.abs(parseFloat(position.notional) || 0)
            const positionAmt = parseFloat(position.positionAmt) || 0
            const initialMargin = Math.abs(parseFloat(position.initialMargin) || 0)
            const isolatedMargin = Math.abs(parseFloat(position.isolatedMargin) || 0)
            
            // 使用API返回的标记价格，如果没有则计算
            let markPrice = parseFloat(position.markPrice) || 0
            if (markPrice === 0 && positionAmt !== 0) {
              // 如果没有markPrice字段，则通过名义价值计算
              markPrice = notional / Math.abs(positionAmt)
            }
            
            // 计算入场价（平均成本/开仓价格）
            let entryPrice = 0
            if (positionAmt !== 0) {
              // 根据仓位方向计算入场价
              if (position.positionSide === 'SHORT') {
                // 空头：入场价 = (名义价值 + 未实现盈亏) / 持仓数量绝对值
                // 空头盈利时未实现盈亏是负数，所以用加法
                entryPrice = (notional + unrealizedPnl) / Math.abs(positionAmt)
              } else {
                // 多头：入场价 = (名义价值 - 未实现盈亏) / 持仓数量绝对值
                entryPrice = (notional - unrealizedPnl) / Math.abs(positionAmt)
              }
              
              // 确保入场价显示为正数
              entryPrice = Math.abs(entryPrice)
              
              // 调试信息
              console.log(`${position.symbol} ${position.positionSide} 入场价计算:`, {
                notional: notional,
                unrealizedPnl: unrealizedPnl,
                positionAmt: positionAmt,
                absPositionAmt: Math.abs(positionAmt),
                calculatedEntryPrice: entryPrice,
                side: position.positionSide,
                formula: position.positionSide === 'SHORT' ? '(notional + unrealizedPnl) / abs(positionAmt)' : '(notional - unrealizedPnl) / abs(positionAmt)'
              })
            }
            
            // 计算杠杆倍数：名义价值 / 初始保证金
            let calculatedLeverage = 0
            if (initialMargin > 0) {
              calculatedLeverage = notional / initialMargin
            }
            
            // 计算保证金：名义价值 / 杠杆倍数
            let calculatedMargin = 0
            if (calculatedLeverage > 0) {
              calculatedMargin = notional / calculatedLeverage
            }
            
            // 计算收益率：未实现盈亏 / 初始保证金 * 100
            // 使用初始保证金计算收益率，这样更符合实际交易逻辑
            let calculatedPercentage = 0
            if (initialMargin > 0) {
              calculatedPercentage = (unrealizedPnl / initialMargin) * 100
            }
            
            // 确保收益率显示正确的符号
            if (position.positionSide === 'SHORT' && unrealizedPnl < 0) {
              // 空头亏损时，收益率应该是负数
              calculatedPercentage = -Math.abs(calculatedPercentage)
            }
            
            // 调试信息
            console.log(`${position.symbol} ${position.positionSide}: 原始数据:`, {
              positionAmt: positionAmt,
              notional: notional,
              unrealizedPnl: unrealizedPnl,
              initialMargin: initialMargin
            })
            const priceSource = position.markPrice ? 'API提供' : '计算得出'
            console.log(`${position.symbol} ${position.positionSide}: 入场价=${entryPrice.toFixed(6)}, 标记价=${markPrice.toFixed(6)} (${priceSource})`)
            console.log(`${position.symbol} ${position.positionSide}: 初始保证金=${initialMargin.toFixed(6)}, 盈亏=${unrealizedPnl.toFixed(2)}, 收益率=${calculatedPercentage.toFixed(2)}% (基于初始保证金)`)
            console.log(`${position.symbol} ${position.positionSide}: 计算杠杆=${calculatedLeverage.toFixed(2)}x, 计算保证金=${calculatedMargin.toFixed(6)} (名义价值=${notional.toFixed(6)} / 杠杆=${calculatedLeverage.toFixed(2)})`)
            console.log(`${position.symbol} ${position.positionSide}: 存储原始保证金=${initialMargin.toFixed(6)} 用于WebSocket计算`)
            console.log(`${position.symbol} ${position.positionSide}: 维持保证金=${parseFloat(position.maintMargin).toFixed(6)}, 逐仓保证金=${isolatedMargin.toFixed(6)}`)
            
            return {
              id: `${user.id}_${position.symbol}_${position.positionSide}`,
              symbol: position.symbol,
              side: position.positionSide,
              amount: Math.abs(positionAmt), // 持仓数量取绝对值
              entryPrice: entryPrice, // 计算出的入场价（平均成本）
              markPrice: markPrice, // 计算出的标记价（当前价格）
              unrealizedPnl: unrealizedPnl,
              percentage: calculatedPercentage,
              notional: notional, // 名义价值
              margin: calculatedMargin, // 使用计算出的保证金
              marginType: 'contract', // 合约类型
              leverage: calculatedLeverage, // 使用计算出的杠杆
              marginUsageRatio: 0, // 新字段中没有保证金使用率，设为0
              actualMargin: isolatedMargin, // 逐仓保证金
              isolatedWallet: parseFloat(position.isolatedWallet) || 0, // 逐仓钱包
              maintMargin: parseFloat(position.maintMargin) || 0, // 维持保证金
              updateTime: position.updateTime, // 更新时间
              priceUpdateTime: position.price_update_time, // 价格更新时间
              // 保存原始数据用于WebSocket计算
              originalEntryPrice: entryPrice, // 原始入场价
              originalUnrealizedPnl: unrealizedPnl, // 原始未实现盈亏
              originalNotional: notional, // 原始名义价值
              originalMargin: initialMargin, // 原始保证金（API返回的初始保证金）
              originalLeverage: calculatedLeverage, // 原始杠杆（计算得出）
              calculatedEntryPrice: entryPrice, // 计算出的入场价（用于调试）
              apiMarkPrice: markPrice // API提供的标记价（用于调试）
            }
          })
          
          // 强制更新响应式数据
          user.positions.splice(0, user.positions.length, ...newPositions)
          console.log(`更新用户 ${user.alias} 的仓位数据:`, user.positions.length, '个仓位')
        } else if (user) {
          // 用户存在但没有仓位数据
          user.positions.splice(0, user.positions.length)
          console.log(`用户 ${user.alias} 没有仓位数据`)
        }
      })
      
      // 更新最后更新时间
      lastUpdateTime.value = new Date()
    }
  } catch (error) {
    console.error('获取仓位数据失败:', error)
  } finally {
    positionsLoading.value = false
  }
}

// 刷新单个用户的仓位数据
async function refreshUserPositions(userId) {
  const user = users.value.find(u => u.id === userId)
  if (!user) return
  
  try {
    console.log(`刷新用户 ${user.alias} 的仓位数据...`)
    // 这里可以调用单个用户的仓位接口，暂时使用批量接口
    await fetchAllPositions()
  } catch (error) {
    console.error(`刷新用户 ${user.alias} 仓位数据失败:`, error)
  }
}


function updateRefreshRate(value) {
  refreshRate.value = value
  if (autoRefresh.value) {
    startAutoRefresh()
  }
}

// 获取所有用户的挂单数据
async function fetchAllOrders() {
  try {
    ordersLoading.value = true
    console.log('开始获取所有用户挂单数据...')
    
    const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/orders/all`)
    console.log('挂单数据响应:', response.data)
    
    if (response.data && response.data.success && response.data.data && Array.isArray(response.data.data.users)) {
      // 处理每个用户的挂单数据
      response.data.data.users.forEach(userData => {
        // 找到对应用户
        const user = users.value.find(u => u.alias === userData.alias)
        
        if (user && userData.orders && userData.orders.length > 0) {
          // 转换挂单数据格式
          const newOrders = userData.orders.map(order => ({
            id: `${user.id}_${order.orderId}`,
            orderId: order.orderId,
            symbol: order.symbol,
            side: order.side,
            type: order.type,
            price: parseFloat(order.price),
            origQty: parseFloat(order.origQty),
            executedQty: parseFloat(order.executedQty),
            cumQuote: parseFloat(order.cumQuote),
            status: order.status,
            timeInForce: order.timeInForce,
            stopPrice: parseFloat(order.stopPrice),
            time: order.time,
            updateTime: order.updateTime,
            positionSide: order.positionSide,
            reduceOnly: order.reduceOnly,
            closePosition: order.closePosition,
            clientOrderId: order.clientOrderId,
            origType: order.origType,
            workingType: order.workingType
          }))
          
          // 强制更新响应式数据
          user.orders.splice(0, user.orders.length, ...newOrders)
          console.log(`更新用户 ${user.alias} 的挂单数据:`, user.orders.length, '个挂单')
        } else if (user) {
          // 用户存在但没有挂单数据
          user.orders.splice(0, user.orders.length)
          console.log(`用户 ${user.alias} 没有挂单数据`)
        }
      })
    }
  } catch (error) {
    console.error('获取挂单数据失败:', error)
  } finally {
    ordersLoading.value = false
  }
}

// WebSocket连接管理
let wsConnection = null

// 更新仓位价格
function updatePositionPrices(symbol, currentPrice) {
  let hasUpdate = false
  
  users.value.forEach(user => {
    user.positions.forEach((position, index) => {
      if (position.symbol === symbol) {
        // 获取原始数据（从API获取的固定数据，刷新时更新）
        const originalEntryPrice = position.originalEntryPrice || position.entryPrice
        const originalAmount = position.amount
        const originalMargin = position.originalMargin || position.margin
        const originalLeverage = position.originalLeverage || position.leverage
        const originalUnrealizedPnl = position.originalUnrealizedPnl || position.unrealizedPnl
        
        // 根据新价格重新计算相关字段
        let newUnrealizedPnl = 0
        let newPercentage = 0
        let newNotional = 0
        let newMargin = 0
        let newLeverage = 0
        
        if (originalAmount > 0) {
          // 1. 使用原始入场价（不变），确保为正数
          const entryPrice = Math.abs(originalEntryPrice)
          
          // 2. 根据新价格计算新的未实现盈亏
          if (position.side === 'LONG') {
            // 多头：(当前价格 - 入场价) × 持仓数量
            newUnrealizedPnl = (currentPrice - entryPrice) * originalAmount
          } else {
            // 空头：(入场价 - 当前价格) × 持仓数量绝对值
            // 空头盈利：当前价格 < 入场价
            // 空头亏损：当前价格 > 入场价
            newUnrealizedPnl = (entryPrice - currentPrice) * originalAmount
          }
          
          // 3. 重新计算名义价值
          newNotional = currentPrice * originalAmount
          
          // 4. 重新计算收益率：未实现盈亏 / 初始保证金 * 100
          if (originalMargin > 0) {
            newPercentage = (newUnrealizedPnl / originalMargin) * 100
          }
          
          // 确保空头收益率显示正确的符号
          if (position.side === 'SHORT' && newUnrealizedPnl < 0) {
            newPercentage = -Math.abs(newPercentage)
          }
          
          // 5. 杠杆倍数保持不变（使用原始杠杆）
          newLeverage = position.originalLeverage || position.leverage
          
           // 6. 重新计算保证金：名义价值 / 杠杆倍数
           if (newLeverage > 0) {
             newMargin = newNotional / newLeverage
           }
        }
        
        // 使用Vue的响应式更新方式
        user.positions[index] = {
          ...position,
          markPrice: currentPrice,
          // entryPrice 保持不变，使用原始值
          unrealizedPnl: newUnrealizedPnl,
          percentage: newPercentage,
          notional: newNotional,
          margin: newMargin,
          leverage: newLeverage
        }
        
        hasUpdate = true
        console.log(`更新 ${symbol} 价格: ${currentPrice}`)
        console.log(`原始数据 - 入场价: ${originalEntryPrice.toFixed(6)}, 原始盈亏: ${originalUnrealizedPnl.toFixed(2)}, 原始保证金: ${originalMargin.toFixed(6)}`)
        console.log(`新数据 - 入场价: ${originalEntryPrice.toFixed(6)} (不变), 新盈亏: ${newUnrealizedPnl.toFixed(2)}, 收益率: ${newPercentage.toFixed(2)}% (基于原始保证金: ${originalMargin.toFixed(6)})`)
        console.log(`名义价值: ${position.originalNotional?.toFixed(6) || position.notional.toFixed(6)} → ${newNotional.toFixed(6)}`)
        console.log(`保证金: ${position.originalMargin?.toFixed(6) || position.margin.toFixed(6)} → ${newMargin.toFixed(6)}, 杠杆: ${position.originalLeverage?.toFixed(1) || position.leverage.toFixed(1)}x (保持不变)`)
        if (position.side === 'SHORT') {
          console.log(`空头计算: 入场价=${entryPrice.toFixed(6)}, 当前价=${currentPrice.toFixed(6)}, 持仓量=${originalAmount.toFixed(6)}, 盈亏=${newUnrealizedPnl.toFixed(2)} (入场价-当前价=${(entryPrice - currentPrice).toFixed(6)})`)
        }
      }
    })
  })
  
  // 强制触发响应式更新
  if (hasUpdate) {
    // 触发Vue的响应式更新
    users.value = [...users.value]
  }
}

// 启动WebSocket价格订阅
function startWebSocketSubscription() {
  if (wsConnection) {
    wsConnection.close()
  }
  
  // 获取所有需要订阅的交易对
  const symbols = new Set()
  users.value.forEach(user => {
    user.positions.forEach(position => {
      if (position.symbol) {
        symbols.add(position.symbol.toLowerCase())
      }
    })
  })
  
  if (symbols.size === 0) {
    console.log('没有需要订阅的交易对')
    return
  }
  
  // 连接币安WebSocket（全市场ticker流）
  wsConnection = new WebSocket('wss://fstream.binance.com/ws/!ticker@arr')
  
  wsConnection.onopen = () => {
    console.log('WebSocket连接已建立，订阅全市场ticker')
    console.log('需要监控的交易对:', Array.from(symbols))
  }
  
  wsConnection.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data)
      if (Array.isArray(data)) {
        // 处理ticker数据，只更新我们需要的交易对
        data.forEach(ticker => {
          if (ticker.s && ticker.c && symbols.has(ticker.s.toLowerCase())) {
            updatePositionPrices(ticker.s, parseFloat(ticker.c))
          }
        })
      }
    } catch (error) {
      console.error('WebSocket消息解析错误:', error)
    }
  }
  
  wsConnection.onclose = () => {
    console.log('WebSocket连接已关闭')
    // 5秒后重连
    setTimeout(() => {
      if (autoRefresh.value) {
        startWebSocketSubscription()
      }
    }, 5000)
  }
  
  wsConnection.onerror = (error) => {
    console.error('WebSocket错误:', error)
  }
}

// 自动刷新控制（现在只控制WebSocket）
function startAutoRefresh() {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
  }
  
  if (autoRefresh.value) {
    // 启动WebSocket订阅
    startWebSocketSubscription()
    console.log('开始WebSocket价格订阅')
  }
}

function stopAutoRefresh() {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
    refreshInterval.value = null
  }
  
  if (wsConnection) {
    wsConnection.close()
    wsConnection = null
    console.log('停止WebSocket价格订阅')
  }
}

function toggleAutoRefresh(value) {
  autoRefresh.value = value
  if (value) {
    startAutoRefresh()
  } else {
    stopAutoRefresh()
  }
}

// 强制刷新所有数据
async function forceRefresh() {
  console.log('强制刷新所有数据...')
  await fetchUsers()
  await fetchAllPositions()
  await fetchAllOrders()
  
  // 刷新后重新启动WebSocket订阅
  if (autoRefresh.value) {
    startWebSocketSubscription()
  }
}

// 只刷新仓位数据
async function refreshPositions() {
  console.log('刷新仓位数据...')
  await fetchAllPositions()
  lastUpdateTime.value = new Date()
  console.log('仓位刷新完成')
  
  // 重新启动WebSocket订阅（基于新的原始数据）
  if (autoRefresh.value) {
    startWebSocketSubscription()
  }
}

// 只刷新挂单数据
async function refreshOrders() {
  console.log('刷新挂单数据...')
  await fetchAllOrders()
  console.log('挂单刷新完成')
}

// 批量下单相关方法
function openBatchOrderModal() {
  showBatchOrderModal.value = true
  selectedUsers.value = []
  loadAvailableSymbols()
}

function loadAvailableSymbols() {
  // 从现有仓位数据中提取交易对
  const symbols = new Set()
  users.value.forEach(user => {
    if (user.positions) {
      user.positions.forEach(position => {
        symbols.add(position.symbol)
      })
    }
  })
  availableSymbols.value = Array.from(symbols).map(symbol => ({
    label: symbol,
    value: symbol
  }))
}

async function onSymbolChange(symbol) {
  if (symbol) {
    try {
      // 查询该交易对的详细信息
      const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/symbol/info/${symbol}`)
      if (response.data && response.data.success) {
        const info = response.data.data
        symbolInfo.value = info
        
        // 更新相关限制
        maxLeverage.value = info.maxLeverage || 1
        minQuantityByNotional.value = info.minQuantityByNotional || 0.001
        minQuantityUSDT.value = info.minQuantityUSDT || 10
        tickSize.value = info.tickSize || 0.1
        
        // 调整当前杠杆不超过最大值
        batchOrderForm.value.leverage = Math.min(batchOrderForm.value.leverage, maxLeverage.value)
        
        console.log(`${symbol} 交易对信息:`, info)
      }
    } catch (error) {
      console.error('获取交易对信息失败:', error)
      // 重置为默认值
      maxLeverage.value = 1
      minQuantityByNotional.value = 0.001
      minQuantityUSDT.value = 10
      tickSize.value = 0.1
    }
  }
}

async function submitBatchOrder() {
  if (selectedUsers.value.length === 0) {
    alert('请选择至少一个用户')
    return
  }
  
  if (!batchOrderForm.value.symbol) {
    alert('请选择交易对')
    return
  }
  
  if (!batchOrderForm.value.percentage || batchOrderForm.value.percentage <= 0) {
    alert('请输入有效的仓位百分比')
    return
  }
  
  // 验证每个用户的下单量是否满足最小USDT要求
  const invalidUsers = []
  selectedUsers.value.forEach(userId => {
    const user = users.value.find(u => u.id === userId)
    if (user && user.availableBalance) {
      const usdtAmount = user.availableBalance * batchOrderForm.value.percentage / 100
      if (usdtAmount < minQuantityUSDT.value) {
        invalidUsers.push(`${user.alias}($${usdtAmount.toFixed(2)})`)
      }
    }
  })
  
  if (invalidUsers.length > 0) {
    alert(`以下用户下单金额小于最小要求($${minQuantityUSDT.value}): ${invalidUsers.join(', ')}`)
    return
  }
  
  try {
    batchOrderLoading.value = true
    
    // 为每个用户计算具体的下单量
    const userOrders = selectedUsers.value.map(userId => {
      const user = users.value.find(u => u.id === userId)
      if (!user || !user.availableBalance) {
        return {
          user_id: userId,
          usdt_amount: 0
        }
      }
      
      // 计算该用户的下单量：可用余额 × 百分比
      const usdtAmount = (user.availableBalance * batchOrderForm.value.percentage / 100).toFixed(2)
      
      return {
        user_id: userId,
        usdt_amount: parseFloat(usdtAmount)
      }
    })
    
    // 发送多个独立的订单请求，每个用户一个请求
    const orderPromises = userOrders.map(async (userOrder) => {
      const requestData = {
        user_ids: [userOrder.user_id],
        symbol: batchOrderForm.value.symbol,
        side: batchOrderForm.value.side,
        usdt_amount: userOrder.usdt_amount,
        leverage: batchOrderForm.value.leverage
      }
      
      // 添加止盈止损价格（如果设置了）
      if (batchOrderForm.value.takeProfitPrice) {
        requestData.take_profit_price = batchOrderForm.value.takeProfitPrice
      }
      if (batchOrderForm.value.stopLossPrice) {
        requestData.stop_loss_price = batchOrderForm.value.stopLossPrice
      }
      
      console.log(`用户 ${userOrder.user_id} 下单请求:`, requestData)
      
      return axios.post(`${import.meta.env.VITE_API_TRADE}/api/batch/orders`, requestData)
    })
    
    // 等待所有订单请求完成
    const results = await Promise.allSettled(orderPromises)
    
    console.log('批量下单结果:', results)
    
    // 统计成功和失败的数量
    let successCount = 0
    let failedCount = 0
    const failedUsers = []
    
    results.forEach((result, index) => {
      if (result.status === 'fulfilled' && result.value.data && result.value.data.success) {
        successCount++
      } else {
        failedCount++
        const user = users.value.find(u => u.id === userOrders[index].user_id)
        failedUsers.push(user?.alias || `用户${index + 1}`)
      }
    })
    
    if (successCount > 0) {
      let message = `批量下单完成！成功: ${successCount}个`
      if (failedCount > 0) {
        message += `，失败: ${failedCount}个`
        if (failedUsers.length > 0) {
          message += `\n失败用户: ${failedUsers.join(', ')}`
        }
      }
      alert(message)
      showBatchOrderModal.value = false
      // 刷新数据
      await fetchAllPositions()
      await fetchAllOrders()
    } else {
      alert('批量下单失败: 所有用户下单都失败了')
    }
  } catch (error) {
    console.error('批量下单失败:', error)
    alert('批量下单失败: ' + error.message)
  } finally {
    batchOrderLoading.value = false
  }
}

// 组件挂载时获取用户数据
onMounted(async () => {
  await fetchUsers()
  // 获取用户数据后，自动获取仓位和挂单数据
  await fetchAllPositions()
  await fetchAllOrders()
  // 开始自动刷新
  startAutoRefresh()
})

// 组件卸载时清理定时器
onUnmounted(() => {
  stopAutoRefresh()
  if (wsConnection) {
    wsConnection.close()
    wsConnection = null
  }
})

// 监听自动刷新开关变化
watch(autoRefresh, (newValue) => {
  if (newValue) {
    startAutoRefresh()
  } else {
    stopAutoRefresh()
  }
})
</script>

<style scoped>
.user-management {
  padding: 16px;
}

.action-buttons {
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 12px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 8px;
}

.auto-refresh-controls {
  display: flex;
  align-items: center;
  gap: 8px;
}

.control-label {
  font-size: 14px;
  color: var(--n-text-color-2);
  white-space: nowrap;
}

.last-update {
  font-size: 12px;
  color: var(--n-text-color-3);
  margin-left: 8px;
}

.user-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}

.user-card {
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s ease;
  overflow: hidden;
}

.user-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

.user-card.expanded {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid var(--n-border-color);
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: var(--n-color-primary);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 18px;
}

.user-details {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.user-name {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
}

.testnet-badge {
  background: var(--n-color-warning);
  color: white;
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 500;
}

.user-balance {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--n-color-success);
}

.user-wallet-balance {
  margin: 0;
  font-size: 12px;
  color: var(--n-text-color-2);
}

.user-unrealized-pnl {
  margin: 0;
  font-size: 12px;
  font-weight: 600;
}

.user-unrealized-pnl.positive {
  color: var(--n-color-success);
}

.user-unrealized-pnl.negative {
  color: var(--n-color-error);
}

.user-id {
  margin: 0;
  font-size: 12px;
  color: var(--n-text-color-3);
}

.user-created {
  margin: 0;
  font-size: 11px;
  color: var(--n-text-color-3);
}

.user-status {
  display: flex;
  align-items: center;
}

.status-badge {
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
}

.status-badge.online {
  background: #dcfce7;
  color: #16a34a;
}

.status-badge.offline {
  background: #f3f4f6;
  color: #6b7280;
}

.card-content {
  padding: 16px;
  background: var(--n-color-target);
}

.tab-content {
  padding: 16px 0;
}

.positions-header,
.orders-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.positions-header h4,
.orders-header h4 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--n-text-color);
}

.positions-list,
.orders-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.position-item,
.order-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 8px;
}

.position-info,
.order-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.position-details {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.price-info,
.pnl-info,
.margin-info,
.leverage-info,
.additional-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
}

.position-amount-label,
.notional-label,
.margin-label,
.isolated-margin-label,
.maint-margin-label,
.isolated-wallet-label {
  font-weight: 500;
}

.position-side {
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 500;
}

.position-side.long {
  background: #dcfce7;
  color: #16a34a;
}

.position-side.short {
  background: #fef2f2;
  color: #dc2626;
}

.entry-price,
.mark-price {
  color: var(--n-text-color-2);
}

.pnl-value,
.pnl-percentage {
  font-weight: 600;
  font-size: 20px;
}

.pnl-value.positive,
.pnl-percentage.positive {
  color: #16a34a;
}

.pnl-value.negative,
.pnl-percentage.negative {
  color: #dc2626;
}

.notional,
.margin {
  color: var(--n-text-color-3);
}

.leverage {
  color: var(--n-color-primary);
  font-weight: 600;
}

.margin-usage {
  color: var(--n-text-color-2);
}

.actual-margin {
  color: var(--n-text-color-2);
  font-weight: 500;
}

.coin-name {
  font-weight: 600;
  color: var(--n-text-color);
}

.position-amount,
.order-price {
  color: var(--n-text-color-2);
}

.position-value {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}

.value {
  font-weight: 600;
  color: var(--n-text-color);
}

.change {
  font-size: 12px;
  font-weight: 500;
}

.change.positive {
  color: #16a34a;
}

.change.negative {
  color: #dc2626;
}

.order-side {
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.order-side.buy {
  background: #dcfce7;
  color: #16a34a;
}

.order-side.sell {
  background: #fef2f2;
  color: #dc2626;
}

.order-type {
  color: var(--n-text-color-2);
  font-size: 11px;
}

.order-details {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}

.price-qty-info,
.stop-price-info,
.status-time-info,
.execution-info,
.order-flags {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
}

.order-price,
.order-qty {
  color: var(--n-text-color-2);
}

.order-time {
  color: var(--n-text-color-3);
  font-size: 11px;
}

.executed-qty,
.remaining-qty {
  color: var(--n-text-color-2);
  font-size: 11px;
}

.stop-price {
  color: var(--n-color-warning);
  font-weight: 500;
}

.order-flags {
  gap: 4px;
}

.flag {
  padding: 2px 4px;
  border-radius: 3px;
  font-size: 10px;
  font-weight: 500;
}

.flag.reduce-only {
  background: #fef3c7;
  color: #d97706;
}

.flag.close-position {
  background: #fef2f2;
  color: #dc2626;
}

.order-status {
  font-size: 12px;
  padding: 2px 6px;
  border-radius: 4px;
}

.order-status.new {
  background: #dbeafe;
  color: #2563eb;
}

.order-status.partially_filled {
  background: #fef3c7;
  color: #d97706;
}

.order-status.filled {
  background: #dcfce7;
  color: #16a34a;
}

.order-status.canceled {
  background: #f3f4f6;
  color: #6b7280;
}

.order-status.pending_cancel {
  background: #fef2f2;
  color: #dc2626;
}

.order-status.rejected {
  background: #fef2f2;
  color: #dc2626;
}

.order-status.expired {
  background: #f3f4f6;
  color: #6b7280;
}

.loading-state,
.empty-state {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 200px;
  margin: 20px 0;
}

.form-tip {
  margin-left: 8px;
  font-size: 12px;
  color: var(--n-text-color-3);
}

.order-preview {
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 6px;
  padding: 12px;
  max-height: 200px;
  overflow-y: auto;
}

.preview-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 0;
  border-bottom: 1px solid var(--n-border-color);
}

.preview-item:last-child {
  border-bottom: none;
}

.preview-item .user-name {
  font-weight: 500;
  color: var(--n-text-color);
}

.preview-item .amount {
  font-weight: 600;
  color: var(--n-color-primary);
}

.symbol-info {
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 6px;
  padding: 12px;
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 0;
  border-bottom: 1px solid var(--n-border-color);
}

.info-row:last-child {
  border-bottom: none;
}

.info-label {
  font-size: 12px;
  color: var(--n-text-color-2);
  font-weight: 500;
}

.info-value {
  font-size: 12px;
  color: var(--n-text-color);
  font-weight: 600;
}

.status-trading {
  color: var(--n-color-success);
}

.status-other {
  color: var(--n-color-warning);
}
</style>
