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
                        <div class="position-left">
                          <span class="coin-name">{{ position.symbol }}</span>
                          <span class="position-side" :class="position.side.toLowerCase()">
                            {{ position.side === 'LONG' ? '多' : '空' }}
                          </span>
                          <span class="leverage-badge">{{ position.leverage.toFixed(1) }}x</span>
                        </div>
                        <span v-if="position.liquidation_price_usdt && parseFloat(position.liquidation_price_usdt) > 0" class="liquidation-price">
                          强平: ${{ parseFloat(position.liquidation_price_usdt).toFixed(4) }}
                        </span>
                        <span v-else-if="position.liquidation_price_usdt !== undefined" class="liquidation-price no-liquidation">
                          无强平价
                        </span>
                      </div>
                      <div class="position-details">
                        <div class="price-info">
                          <span class="entry-price">入场价: ${{ position.entryPrice.toFixed(6) }}</span>
                          <span class="mark-price">标记价: ${{ position.markPrice.toFixed(6) }}</span>
                        </div>
            
                        <div class="pnl-info">
                          <span 
                            class="pnl-value" 
                            :class="{
                              'positive': position.unrealizedPnl >= 0, 
                              'negative': position.unrealizedPnl < 0,
                              'highlight': position._highlightProfit
                            }"
                          >
                            {{ position.unrealizedPnl >= 0 ? '+' : '' }}${{ position.unrealizedPnl.toFixed(2) }}
                          </span>
                          <span 
                            class="pnl-percentage" 
                            :class="{
                              'positive': position.percentage >= 0, 
                              'negative': position.percentage < 0,
                              'highlight': position._highlightPercentage
                            }"
                          >
                            {{ position.percentage >= 0 ? '+' : '' }}{{ position.percentage.toFixed(2) }}%
                          </span>
                        </div>
                        <div class="margin-info">
                            <span class="notional-label">持仓数量: ${{ position.notional.toFixed(6) }}</span>
                             <span class="margin-label">保证金: ${{ position.margin.toFixed(6) }}</span>
                        
                        </div>

                      </div>
                      
                      <!-- 仓位操作按钮 -->
                      <div class="position-actions">
                        <n-button 
                          type="error" 
                          size="small" 
                          class="action-btn close-btn"
                          @click="handleClosePosition(position)"
                        >
                          市价平仓
                        </n-button>
                        <n-button 
                          type="warning" 
                          size="small" 
                          class="action-btn tp-sl-btn"
                          @click="handleTpSl(position)"
                        >
                          止盈止损
                        </n-button>
                        <n-button 
                          type="info" 
                          size="small" 
                          class="action-btn leverage-btn"
                          @click="handleModifyLeverage(position)"
                        >
                          修改杠杆
                        </n-button>
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
                  <div class="header-actions">
                    <n-button 
                      size="small" 
                      type="primary" 
                      :loading="ordersLoading"
                      @click="refreshOrders"
                    >
                      刷新挂单
                    </n-button>
                    <n-button 
                      size="small" 
                      type="error" 
                      @click="cancelAllOrders(user)"
                      class="cancel-all-btn"
                    >
                      撤销全部
                    </n-button>
                  </div>
                </div>
                
                <div class="orders-list">
                  <div v-if="user.orders && user.orders.length > 0">
                    <div 
                      v-for="order in user.orders" 
                      :key="order.id"
                      class="order-item"
                    >
                      <div class="order-header">
                        <div class="order-type-badge">
                          <span class="order-type" :class="getOrderTypeClass(order.type)">{{ getOrderTypeText(order.type) }}</span>
                          <span v-if="order.reduceOnly" class="reduce-only-flag">只减仓</span>
                        </div>
                        <div class="order-time">{{ formatOrderTime(order.time) }}</div>
                      </div>
                      
                      <div class="order-content">
                        <div class="order-main-info">
                          <div class="symbol-side">
                            <span class="coin-name">{{ order.symbol }}</span>
                            <span class="order-side" :class="order.side.toLowerCase()">
                              {{ order.side === 'BUY' ? '买入' : '卖出' }}
                            </span>
                          </div>
                          
                          <div class="trigger-price">
                            <span class="price-label">触发价格:</span>
                            <span class="price-value">
                              {{ order.side === 'BUY' ? '≥' : '≤' }}${{ getTriggerPrice(order).toFixed(6) }}
                            </span>
                          </div>
                          
                          <div class="quantity-info">
                            <div class="quantity-item">
                              <span class="qty-label">数量:</span>
                              <span class="qty-value">{{ order.origQty.toFixed(6) }} {{ order.symbol.replace('USDT', '') }}</span>
                            </div>
                            <div class="quantity-item">
                              <span class="qty-label">USDT:</span>
                              <span class="qty-value">${{ (order.origQty * getTriggerPrice(order)).toFixed(2) }}</span>
                            </div>
                          </div>
                        </div>
                        
                        <!-- <div class="order-status">
                          <span class="status-badge" :class="order.status.toLowerCase()">
                            {{ getOrderStatusText(order.status) }}
                          </span>
                        </div> -->
                        
                        <!-- 撤单按钮 - 右下角 -->
                        <div class="order-actions">
                          <n-button 
                            size="small" 
                            type="error" 
                            :disabled="order.status !== 'NEW'"
                            @click="cancelOrder(order)"
                            class="cancel-order-btn"
                          >
                            撤单
                          </n-button>
                          <n-button 
                            size="small" 
                            type="warning" 
                            :disabled="order.status !== 'NEW'"
                            @click="batchCancelOrder(order)"
                            class="batch-cancel-btn"
                          >
                            批量撤单
                          </n-button>
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
          <div style="margin-bottom: 12px;">
            <n-checkbox v-model:checked="useAllUsers" @update:checked="onAllUsersChange">
              全部用户下单
            </n-checkbox>
          </div>
          <n-checkbox-group v-model:value="selectedUsers" :disabled="useAllUsers">
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
            placeholder="搜索或选择交易对"
            :options="availableSymbols"
            :loading="symbolsLoading"
            filterable
            clearable
            @update:value="onSymbolChange"
            @search="onSymbolSearch"
          />
          <div v-if="symbolsLoading" class="loading-text">正在加载交易对列表...</div>
        </n-form-item>
        
        <n-form-item v-if="batchOrderForm.symbol && maxLeverage > 1" label="交易对信息">
          <div class="symbol-info">
            <div class="info-row">
              <span class="info-label">交易对:</span>
              <span class="info-value">{{ batchOrderForm.symbol }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">最大杠杆:</span>
              <span class="info-value">{{ maxLeverage }}x</span>
            </div>
            <div class="info-row">
              <span class="info-label">合约类型:</span>
              <span class="info-value">永续合约</span>
            </div>
            <div class="info-row">
              <span class="info-label">状态:</span>
              <span class="info-value status-trading">交易中</span>
            </div>
          </div>
        </n-form-item>
        
        <n-form-item label="交易方向">
          <n-radio-group v-model:value="batchOrderForm.side">
            <n-radio value="BUY">开多</n-radio>
            <n-radio value="SELL">开空</n-radio>
          </n-radio-group>
        </n-form-item>
        
        <n-form-item label="订单类型">
          <n-radio-group v-model:value="batchOrderForm.orderType">
            <n-radio value="MARKET">市价单</n-radio>
            <n-radio value="LIMIT">限价单</n-radio>
          </n-radio-group>
        </n-form-item>
        
        <n-form-item v-if="batchOrderForm.orderType === 'LIMIT'" label="限价价格">
          <n-input-number 
            v-model:value="batchOrderForm.price" 
            :min="0.000001"
            :precision="6"
            placeholder="输入限价价格"
          />
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
          <div style="width: 100%;">
            <n-slider 
              v-model:value="batchOrderForm.positionPercentage" 
              :min="1"
              :max="100"
              :step="1"
              :marks="{ 25: '25%', 50: '50%', 75: '75%', 100: '100%' }"
              :tooltip="true"
              style="margin-bottom: 20px;"
            />
            <div style="display: flex; justify-content: flex-end; align-items: center; gap: 12px;">
              <n-input-number 
                v-model:value="batchOrderForm.positionPercentage" 
                :min="1"
                :max="100"
                :precision="0"
                size="small"
                style="width: 120px;"
              >
                <template #suffix>
                  %
                </template>
              </n-input-number>
            </div>
            <div style="margin-top: 8px;">
              <span class="form-tip">每个用户将使用可用余额的 {{ batchOrderForm.positionPercentage }}%</span>
            </div>
          </div>
        </n-form-item>
        
        <n-form-item v-if="((useAllUsers && users.length > 0) || selectedUsers.length > 0) && batchOrderForm.symbol" label="下单预览">
          <div class="order-preview">
            <div 
              v-for="userId in (useAllUsers ? users.map(u => u.id) : selectedUsers)" 
              :key="userId"
              class="preview-item"
            >
              <div style="display: flex; flex-direction: column; gap: 4px;">
                <div style="font-weight: bold; color: #1890ff;">{{ getUserById(userId)?.alias }}</div>
                <div style="font-size: 13px;">
                  <span style="color: #666;">交易对:</span> {{ batchOrderForm.symbol }}
                  <span style="color: #666; margin-left: 12px;">方向:</span> 
                  <span :style="{ color: batchOrderForm.side === 'BUY' ? '#52c41a' : '#f5222d', fontWeight: 'bold' }">
                    {{ batchOrderForm.side === 'BUY' ? '开多' : '开空' }}
                  </span>
                </div>
                <div style="font-size: 13px;">
                  <span style="color: #666;">下单金额:</span> 
                  <span style="font-weight: bold; color: #1890ff;">${{ calculateUserOrderAmount(userId).toFixed(2) }} USDT</span>
                  <span style="color: #999; margin-left: 8px;">(余额 ${{ (getUserById(userId)?.availableBalance || 0).toFixed(2) }} × {{ batchOrderForm.positionPercentage }}%)</span>
                </div>
                <div style="font-size: 13px;">
                  <span style="color: #666;">价格:</span> {{ batchOrderForm.orderType === 'MARKET' ? '市价' : '$' + batchOrderForm.price }}
                  <span style="color: #666; margin-left: 12px;">杠杆:</span> 
                  <span style="font-weight: bold;">{{ batchOrderForm.leverage }}x</span>
                </div>
              </div>
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
    
    <!-- 修改杠杆弹窗 -->
    <n-modal v-model:show="modifyLeverageModal.show" :mask-closable="false">
      <n-card
        style="width: 500px; max-width: 90vw"
        title="修改杠杆"
        :bordered="false"
        size="huge"
        role="dialog"
        aria-modal="true"
      >
        <template #header-extra>
          <n-button quaternary circle @click="modifyLeverageModal.show = false">
            ×
          </n-button>
        </template>
        
        <div class="modify-leverage-form">
          <!-- 修改杠杆信息 -->
          <div class="leverage-info">
            <div class="title-main">{{ modifyLeverageModal.symbol }} {{ modifyLeverageModal.side === 'LONG' ? '多头' : '空头' }}</div>
            <div class="title-sub">修改杠杆</div>
            <p class="info-text">将为所有持有该币种且方向一致的用户修改杠杆倍数</p>
          </div>
          
          <!-- 杠杆选择 -->
          <div class="leverage-selector">
            <n-form-item :label="`新杠杆倍数: ${modifyLeverageModal.newLeverage || 1}x`">
              <n-slider
                v-model:value="modifyLeverageModal.newLeverage"
                :min="1"
                :max="modifyLeverageModal.maxLeverage"
                :step="1"
                :marks="modifyLeverageModal.leverageMarks"
                :tooltip="false"
                @update:value="updateLeverageInfo"
              />
            </n-form-item>
          </div>
          
          <!-- 用户列表 -->
          <div class="users-list">
            <h5>修改杠杆用户列表</h5>
            <div class="users-container">
              <div 
                v-for="user in modifyLeverageModal.affectedUsers" 
                :key="user.id"
                class="user-item"
              >
                <div class="user-info">
                  <span class="user-name">{{ user.alias }}</span>
                  <span class="position-info">
                    持仓: {{ user.position.amount.toFixed(6) }} {{ modifyLeverageModal.symbol.replace('USDT', '') }}
                  </span>
                </div>
                <div class="leverage-info">
                  <span class="current-leverage">
                    当前杠杆: {{ user.position.leverage.toFixed(1) }}x
                  </span>
                  <span class="new-leverage">
                    新杠杆: {{ modifyLeverageModal.newLeverage || '未选择' }}x
                  </span>
                </div>
              </div>
            </div>
          </div>
          
          <!-- 总计信息 -->
          <div class="total-info">
            <div class="total-item">
              <span class="label">修改用户数:</span>
              <span class="value">{{ modifyLeverageModal.affectedUsers.length }} 人</span>
            </div>
            <div class="total-item">
              <span class="label">当前杠杆:</span>
              <span class="value">{{ modifyLeverageModal.currentLeverage }}x</span>
            </div>
            <div class="total-item">
              <span class="label">新杠杆:</span>
              <span class="value">{{ modifyLeverageModal.newLeverage || '未选择' }}x</span>
            </div>
          </div>
        </div>
        
        <template #action>
          <div class="modal-actions">
            <n-button @click="modifyLeverageModal.show = false">取消</n-button>
            <n-button 
              type="primary" 
              :loading="modifyLeverageModal.loading"
              :disabled="!modifyLeverageModal.newLeverage"
              @click="confirmModifyLeverage"
            >
              确认修改
            </n-button>
          </div>
        </template>
      </n-card>
    </n-modal>
    
    <!-- 止盈止损弹窗 -->
    <n-modal v-model:show="tpSlModal.show" :mask-closable="false">
      <n-card
        style="width: 600px; max-width: 90vw"
        title="止盈止损设置"
        :bordered="false"
        size="huge"
        role="dialog"
        aria-modal="true"
      >
        <template #header-extra>
          <n-button quaternary circle @click="tpSlModal.show = false">
            ×
          </n-button>
        </template>
        
        <div class="tpsl-form">
          <!-- 止盈止损信息 -->
          <div class="tpsl-info">
            <h4>{{ tpSlModal.symbol }} {{ tpSlModal.side === 'LONG' ? '多头' : '空头' }}</h4>
            <h5>止盈止损设置</h5>
            <p class="info-text">将为所有持有该币种且方向一致的用户设置止盈止损</p>
          </div>
          
          <!-- 止盈设置 -->
          <div class="tpsl-section">
            <div class="section-header">
              <label class="checkbox-label">
                <input 
                  type="checkbox" 
                  :checked="tpSlModal.takeProfit.enabled"
                  @change="handleTakeProfitChange"
                  style="margin-right: 8px;"
                />
                <span class="section-title">止盈设置</span>
              </label>
            </div>
            
            <div v-show="tpSlModal.takeProfit.enabled" class="section-content">
              <n-form-item label="止盈价格">
                <n-input-number
                  v-model:value="tpSlModal.takeProfit.price"
                  :min="0"
                  :precision="6"
                  placeholder="输入止盈价格"
                  :show-button="false"
                  :default-value="null"
                  @update:value="updateTpSlCalculations"
                />
                <span class="form-tip">USDT</span>
              </n-form-item>
              
              <div class="close-ratio-section">
                <n-form-item :label="`止盈平仓比例: ${tpSlModal.takeProfit.closeRatio || 100}%`">
                  <n-slider
                    v-model:value="tpSlModal.takeProfit.closeRatio"
                    :min="1"
                    :max="100"
                    :step="1"
                    :marks="percentageMarks"
                    :tooltip="false"
                    @update:value="updateTpSlCalculations"
                  />
                </n-form-item>
              </div>
            </div>
          </div>
          
          <!-- 止损设置 -->
          <div class="tpsl-section">
            <div class="section-header">
              <label class="checkbox-label">
                <input 
                  type="checkbox" 
                  :checked="tpSlModal.stopLoss.enabled"
                  @change="handleStopLossChange"
                  style="margin-right: 8px;"
                />
                <span class="section-title">止损设置</span>
              </label>
            </div>
            
            <div v-show="tpSlModal.stopLoss.enabled" class="section-content">
              <n-form-item label="止损价格">
                <n-input-number
                  v-model:value="tpSlModal.stopLoss.price"
                  :min="0"
                  :precision="6"
                  placeholder="输入止损价格"
                  :show-button="false"
                  :default-value="null"
                  @update:value="updateTpSlCalculations"
                />
                <span class="form-tip">USDT</span>
              </n-form-item>
              
              <div class="close-ratio-section">
                <n-form-item :label="`止损平仓比例: ${tpSlModal.stopLoss.closeRatio || 100}%`">
                  <n-slider
                    v-model:value="tpSlModal.stopLoss.closeRatio"
                    :min="1"
                    :max="100"
                    :step="1"
                    :marks="percentageMarks"
                    :tooltip="false"
                    @update:value="updateTpSlCalculations"
                  />
                </n-form-item>
              </div>
            </div>
          </div>
          
          
          <!-- 用户列表和预计盈亏 -->
          <div class="users-list">
            <h5>受影响用户</h5>
            <div class="users-container">
              <div 
                v-for="user in tpSlModal.affectedUsers" 
                :key="user.id"
                class="user-item"
              >
                <div class="user-info">
                  <span class="user-name">{{ user.alias }}</span>
                  <span class="position-info">
                    持仓: {{ user.position.amount.toFixed(6) }} {{ tpSlModal.symbol.replace('USDT', '') }}
                  </span>
                </div>
                <div class="profit-info">
                  <div style="color: red; font-size: 12px; margin-bottom: 5px;">
                    调试: position={{ !!user.position }}, unrealizedPnl={{ user.position?.unrealizedPnl }}<br/>
                    入场价={{ user.position?.entryPrice }}, 持仓={{ user.position?.amount }}, 杠杆={{ user.position?.leverage }}<br/>
                    止盈价={{ tpSlModal.takeProfit.price }}, 止损价={{ tpSlModal.stopLoss.price }}<br/>
                    止盈启用={{ tpSlModal.takeProfit.enabled }}, 止损启用={{ tpSlModal.stopLoss.enabled }}<br/>
                    expectedTp={{ user.expectedTpProfit }}, expectedSl={{ user.expectedSlLoss }}
                  </div>
                  <span class="current-profit" :class="user.position?.unrealizedPnl >= 0 ? 'positive' : 'negative'">
                    当前盈亏: {{ user.position?.unrealizedPnl >= 0 ? '+' : '' }}${{ (user.position?.unrealizedPnl || 0).toFixed(2) }}
                  </span>
                  <span class="expected-profit" :class="user.expectedTpProfit >= 0 ? 'positive' : 'negative'">
                    预计止盈: {{ user.expectedTpProfit >= 0 ? '+' : '' }}${{ formatNumber(user.expectedTpProfit) }}
                  </span>
                  <span class="expected-loss" :class="user.expectedSlLoss >= 0 ? 'positive' : 'negative'">
                    预计止损: {{ user.expectedSlLoss >= 0 ? '+' : '' }}${{ formatNumber(user.expectedSlLoss) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <template #action>
          <div class="modal-actions">
            <n-button @click="tpSlModal.show = false">取消</n-button>
            <n-button 
              type="primary" 
              :loading="tpSlModal.loading"
              :disabled="!tpSlModal.takeProfit.enabled && !tpSlModal.stopLoss.enabled"
              @click="confirmTpSl"
            >
              确认设置
            </n-button>
          </div>
        </template>
      </n-card>
    </n-modal>
    
    <!-- 市价平仓弹窗 -->
    <n-modal v-model:show="closePositionModal.show" :mask-closable="false">
      <n-card
        style="width: 600px; max-width: 90vw"
        title="市价平仓"
        :bordered="false"
        size="huge"
        role="dialog"
        aria-modal="true"
      >
        <template #header-extra>
          <n-button quaternary circle @click="closePositionModal.show = false">
            ×
          </n-button>
        </template>
        
        <div class="close-position-form">
          <!-- 平仓信息 -->
          <div class="close-info">
            <h4>{{ closePositionModal.symbol }} {{ closePositionModal.side === 'LONG' ? '多头' : '空头' }} 平仓</h4>
            <p class="info-text">将为所有持有该币种且方向一致的用户进行平仓操作</p>
          </div>
          
          <!-- 平仓百分比滑块 -->
          <div class="percentage-slider">
            <n-form-item :label="`平仓百分比: ${closePositionModal.percentage}%`">
              <n-slider
                v-model:value="closePositionModal.percentage"
                :min="0"
                :max="100"
                :step="1"
                :marks="percentageMarks"
                :tooltip="false"
              />
            </n-form-item>
          </div>
          
          <!-- 用户列表 -->
          <div class="users-list">
            <h5>平仓用户列表</h5>
            <div class="users-container">
              <div 
                v-for="user in closePositionModal.affectedUsers" 
                :key="user.id"
                class="user-item"
              >
                <div class="user-info">
                  <span class="user-name">{{ user.alias }}</span>
                  <span class="position-info">
                    持仓: {{ user.position.amount.toFixed(6) }} {{ closePositionModal.symbol.replace('USDT', '') }}
                  </span>
                </div>
                <div class="profit-info">
                  <span class="current-profit" :class="getCurrentProfit(user) >= 0 ? 'positive' : 'negative'">
                    当前盈亏: {{ getCurrentProfit(user) >= 0 ? '+' : '' }}${{ getCurrentProfit(user).toFixed(2) }}
                  </span>
                  <span class="expected-profit" :class="user.expectedProfit >= 0 ? 'positive' : 'negative'">
                    预计收益: {{ user.expectedProfit >= 0 ? '+' : '' }}${{ user.expectedProfit.toFixed(2) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          
          <!-- 总计信息 -->
          <div class="total-info">
            <div class="total-item">
              <span class="label">平仓用户数:</span>
              <span class="value">{{ closePositionModal.affectedUsers.length }} 人</span>
            </div>
            <div class="total-item">
              <span class="label">总预计收益:</span>
              <span class="value" :class="closePositionModal.totalExpectedProfit >= 0 ? 'positive' : 'negative'">
                {{ closePositionModal.totalExpectedProfit >= 0 ? '+' : '' }}${{ closePositionModal.totalExpectedProfit.toFixed(2) }}
              </span>
            </div>
          </div>
        </div>
        
        <template #action>
          <div class="modal-actions">
            <n-button @click="closePositionModal.show = false">取消</n-button>
            <n-button 
              type="error" 
              :loading="closePositionModal.loading"
              @click="confirmClosePosition"
            >
              确认平仓
            </n-button>
          </div>
        </template>
      </n-card>
    </n-modal>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { NTabs, NTabPane, NButton, NEmpty, NSwitch, NInputNumber, NModal, NForm, NFormItem, NSelect, NInput, NRadioGroup, NRadio, NCard, NCheckbox, NCheckboxGroup, NDivider, NAlert, NIcon, NSlider } from 'naive-ui'
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
const useAllUsers = ref(false)
const batchOrderForm = ref({
  symbol: '',
  side: 'BUY',
  orderType: 'MARKET',
  price: null,
  leverage: 1,
  positionPercentage: 50, // 仓位百分比，默认50%
  takeProfitPrice: null,
  stopLossPrice: null
})
const availableSymbols = ref([])
const symbolInfo = ref({})
const maxLeverage = ref(1)

// 市价平仓相关
const closePositionModal = ref({
  show: false,
  symbol: '',
  side: '',
  percentage: 100,
  affectedUsers: [],
  totalExpectedProfit: 0,
  loading: false
})

// 百分比滑块标记
const percentageMarks = ref({
  0: '0%',
  25: '25%',
  50: '50%',
  75: '75%',
  100: '100%'
})

// 修改杠杆相关
const modifyLeverageModal = ref({
  show: false,
  symbol: '',
  side: '',
  currentLeverage: 0,
  newLeverage: 1,
  maxLeverage: 1,
  affectedUsers: [],
  leverageMarks: {},
  loading: false
})

// 止盈止损相关
const tpSlModal = ref({
  show: false,
  symbol: '',
  side: '',
  closeRatio: 100,
  affectedUsers: [],
  takeProfit: {
    enabled: false,
    price: null,
    closeRatio: 100
  },
  stopLoss: {
    enabled: false,
    price: null,
    closeRatio: 100
  },
  loading: false
})
const minQuantityByNotional = ref(0.001)
const minQuantityUSDT = ref(10)
const tickSize = ref(0.1)
const symbolsLoading = ref(false)

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

function getOrderTypeClass(type) {
  const classMap = {
    'LIMIT': 'limit',
    'MARKET': 'market',
    'STOP_MARKET': 'stop-market',
    'TAKE_PROFIT_MARKET': 'take-profit-market',
    'STOP_LOSS_LIMIT': 'stop-loss-limit',
    'TAKE_PROFIT_LIMIT': 'take-profit-limit'
  }
  return classMap[type] || 'default'
}

function getTriggerPrice(order) {
  // 对于止损和止盈订单，使用 stopPrice
  if (order.type === 'STOP_MARKET' || 
      order.type === 'TAKE_PROFIT_MARKET' || 
      order.type === 'STOP_LOSS_LIMIT' || 
      order.type === 'TAKE_PROFIT_LIMIT') {
    return order.stopPrice || 0
  }
  // 对于限价单和市价单，使用 price
  return order.price || 0
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
            console.log(`${position.symbol} ${position.positionSide}: 维持保证金=${parseFloat(position.maintMargin).toFixed(6)}, 逐仓保证金=${isolatedMargin.toFixed(6)}`)
            console.log(`${position.symbol} ${position.positionSide}: 强平价格=${position.liquidation_price_usdt || '无'}`)
            
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
              liquidation_price_usdt: position.liquidation_price_usdt, // 强平价格
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
      
      // 重新启动WebSocket订阅（确保新仓位的币种也被订阅）
      if (autoRefresh.value) {
        startWebSocketSubscription()
      }
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
     //     console.log(`更新用户 ${user.alias} 的挂单数据:`, user.orders.length, '个挂单')
        } else if (user) {
          // 用户存在但没有挂单数据
          user.orders.splice(0, user.orders.length)
     //     console.log(`用户 ${user.alias} 没有挂单数据`)
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
let wsHeartbeatInterval = null
let wsLastMessageTime = 0

// 更新仓位价格
function updatePositionPrices(symbol, currentPrice) {
 // console.log(`🔍 查找需要更新价格的仓位: ${symbol} = $${currentPrice}`)
  let hasUpdate = false
  let foundPositions = 0
  
  users.value.forEach(user => {
    user.positions.forEach((position, index) => {
      if (position.symbol === symbol) {
        foundPositions++
      //  console.log(`📍 找到匹配仓位: 用户=${user.alias}, 仓位=${position.symbol}, 当前盈亏=${position.unrealizedPnl}`)
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
        
        // 检查数值是否发生变化，添加高亮效果
        const profitChanged = Math.abs(position.unrealizedPnl - newUnrealizedPnl) > 0.01
        const percentageChanged = Math.abs(position.percentage - newPercentage) > 0.01
        
        // 使用Vue的响应式更新方式
        user.positions[index] = {
          ...position,
          markPrice: currentPrice,
          // entryPrice 保持不变，使用原始值
          unrealizedPnl: newUnrealizedPnl,
          percentage: newPercentage,
          notional: newNotional,
          margin: newMargin,
          leverage: newLeverage,
          // 添加高亮标记
          _highlightProfit: profitChanged,
          _highlightPercentage: percentageChanged
        }
        
        // 清除高亮效果（1秒后）
        if (profitChanged || percentageChanged) {
          setTimeout(() => {
            if (user.positions[index]) {
              user.positions[index]._highlightProfit = false
              user.positions[index]._highlightPercentage = false
            }
          }, 1000)
        }
        
        hasUpdate = true
        // console.log(`更新 ${symbol} 价格: ${currentPrice}`)
        // console.log(`原始数据 - 入场价: ${originalEntryPrice.toFixed(6)}, 原始盈亏: ${originalUnrealizedPnl.toFixed(2)}, 原始保证金: ${originalMargin.toFixed(6)}`)
        // console.log(`新数据 - 入场价: ${originalEntryPrice.toFixed(6)} (不变), 新盈亏: ${newUnrealizedPnl.toFixed(2)}, 收益率: ${newPercentage.toFixed(2)}% (基于原始保证金: ${originalMargin.toFixed(6)})`)
        // console.log(`名义价值: ${position.originalNotional?.toFixed(6) || position.notional.toFixed(6)} → ${newNotional.toFixed(6)}`)
        // console.log(`保证金: ${position.originalMargin?.toFixed(6) || position.margin.toFixed(6)} → ${newMargin.toFixed(6)}, 杠杆: ${position.originalLeverage?.toFixed(1) || position.leverage.toFixed(1)}x (保持不变)`)
        if (position.side === 'SHORT') {
          console.log(`空头计算: 入场价=${entryPrice.toFixed(6)}, 当前价=${currentPrice.toFixed(6)}, 持仓量=${originalAmount.toFixed(6)}, 盈亏=${newUnrealizedPnl.toFixed(2)} (入场价-当前价=${(entryPrice - currentPrice).toFixed(6)})`)
        }
      }
    })
  })
  
  console.log(`📊 价格更新总结: 找到 ${foundPositions} 个匹配仓位，更新了 ${hasUpdate ? '是' : '否'}`)
  
  // 强制触发响应式更新
  if (hasUpdate) {
    // 触发Vue的响应式更新
    users.value = [...users.value]
  }
}

// 启动WebSocket价格订阅
function startWebSocketSubscription() {
  // 收集所有要订阅的 symbol
  const symbols = new Set()
  users.value.forEach(user => {
    user.positions.forEach(pos => {
      if (pos.symbol) symbols.add(pos.symbol.toLowerCase())
    })
  })

  if (symbols.size === 0) {
    console.log('📭 没有仓位需要订阅 WebSocket')
    return
  }

  // 生成多流订阅 URL（示例：btcusdt@ticker/ethusdt@ticker）
  const streams = Array.from(symbols).map(s => `${s}@ticker`).join('/')
  const wsUrl = `wss://fstream.binance.com/stream?streams=${streams}`

  console.log('🔗 启动 WebSocket 订阅:', wsUrl)

  // 如果已有连接存在，先安全关闭
  if (wsConnection && wsConnection.readyState === WebSocket.OPEN) {
    try {
      wsConnection.close(1000, 'restart')
    } catch (_) {}
  }

  wsConnection = new WebSocket(wsUrl)

  wsConnection.onopen = () => {
    console.log('✅ WebSocket 已连接')
    wsLastMessageTime = Date.now()
    startHeartbeat()
  }

  wsConnection.onmessage = (event) => {
    wsLastMessageTime = Date.now()
    try {
      const payload = JSON.parse(event.data)
      const ticker = payload?.data
      if (ticker?.s && ticker?.c) {
        const price = parseFloat(ticker.c)
        updatePositionPrices(ticker.s, price)
      }
    } catch (err) {
      console.warn('⚠️ WebSocket 消息解析错误:', err)
    }
  }

  wsConnection.onerror = (error) => {
    console.error('❌ WebSocket 错误:', error)
  }

  wsConnection.onclose = (event) => {
    console.log(`🔌 WebSocket 关闭: code=${event.code}, reason=${event.reason}`)
    stopHeartbeat()
    // 断线自动重连（5 秒后）
    if (autoRefresh.value) {
      setTimeout(() => startWebSocketSubscription(), 5000)
    }
  }
}

// 🫀 启动心跳检测（每 20 s ping 一次，60 s 超时）
function startHeartbeat() {
  stopHeartbeat()
  wsHeartbeatInterval = setInterval(() => {
    if (!wsConnection) return
    const now = Date.now()
    const idle = now - wsLastMessageTime

    // 发送心跳包（部分客户端不会触发真正 ping/pong，作用是保持活动）
    if (wsConnection.readyState === WebSocket.OPEN) {
      try { wsConnection.send('ping') } catch (_) {}
    }

    // 超过 60 s 未收到消息则判定断线
    if (idle > 60000) {
      console.warn('💔 WebSocket 心跳超时，尝试重连...')
      try { wsConnection.close(4000, 'heartbeat timeout') } catch (_) {}
    }
  }, 20000)
}

// 🛑 停止心跳检测
function stopHeartbeat() {
  if (wsHeartbeatInterval) {
    clearInterval(wsHeartbeatInterval)
    wsHeartbeatInterval = null
  }
}

// ▶️ 启动自动刷新（开启 WebSocket）
function startAutoRefresh() {
  if (refreshInterval.value) clearInterval(refreshInterval.value)
  if (autoRefresh.value) {
    startWebSocketSubscription()
  } else {
    console.log('⏸️ 自动刷新已关闭')
  }
}

// ⏹️ 停止自动刷新（关闭 WebSocket）
function stopAutoRefresh() {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
    refreshInterval.value = null
  }
  if (wsConnection) {
    try { wsConnection.close(1000, 'manual stop') } catch (_) {}
    wsConnection = null
  }
  stopHeartbeat()
}

// 🔄 切换自动刷新状态
function toggleAutoRefresh(value) {
  autoRefresh.value = value
  if (value) startAutoRefresh()
  else stopAutoRefresh()
}

// 🔧 强制刷新所有数据并重建订阅
async function forceRefresh() {
  console.log('🔁 强制刷新所有数据...')
  await fetchUsers()
  await fetchAllPositions()
  await fetchAllOrders()
  if (autoRefresh.value) startWebSocketSubscription()
}

// 🔧 仅刷新仓位并重建订阅
async function refreshPositions() {
  console.log('📈 刷新仓位数据...')
  await fetchAllPositions()
  lastUpdateTime.value = new Date()
  if (autoRefresh.value) startWebSocketSubscription()
}

// 🔧 仅刷新挂单数据
async function refreshOrders() {
  console.log('📋 刷新挂单数据...')
  await fetchAllOrders()
}

// 批量撤单功能
function batchCancelOrder(order) {
  console.log('批量撤单功能待实现:', order)
  // TODO: 实现批量撤单逻辑
}

// 撤销全部功能 - 撤销指定用户的所有订单
async function cancelAllOrders(user) {
  try {
    console.log('开始撤销用户的所有订单:', user.name)
    
    if (!user) {
      alert('用户信息无效')
      return
    }
    
    // 收集该用户的所有NEW状态订单
    const ordersToCancel = []
    
    if (user.orders && user.orders.length > 0) {
      user.orders.forEach(order => {
        if (order.status === 'NEW') {
          ordersToCancel.push({
            user_id: user.id,
            symbol: order.symbol,
            orderId: order.orderId
          })
        }
      })
    }
    
    if (ordersToCancel.length === 0) {
      alert('该用户没有可撤销的订单')
      return
    }
    
    // 准备API请求参数
    const requestData = {
      orders: ordersToCancel
    }
    
    console.log('发送撤销全部请求:', requestData)
    
    // 调用后端API
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/orders/cancel_by_id`, requestData)
    
    console.log('撤销全部响应:', response.data)
    
    if (response.data && response.data.success) {
      alert(`撤销全部成功！共撤销 ${ordersToCancel.length} 个订单`)
      
      // 刷新挂单数据
      await fetchAllOrders()
    } else {
      throw new Error(response.data?.message || '撤销全部失败')
    }
  } catch (error) {
    console.error('撤销全部失败:', error)
    const errorMessage = error.response?.data?.message || error.message || '撤销全部失败'
    alert('撤销全部失败: ' + errorMessage)
  }
}

// 撤单功能 - 撤销单个订单
async function cancelOrder(order) {
  try {
    console.log('开始撤单:', order)
    
    // 获取用户ID
    const userId = users.value.find(u => u.orders?.some(o => o.id === order.id))?.id
    if (!userId) {
      throw new Error('未找到用户ID')
    }
    
    // 准备API请求参数 - 只撤销这一个订单
    const requestData = {
      orders: [
        {
          user_id: userId,
          symbol: order.symbol,
          orderId: order.orderId
        }
      ]
    }
    
    console.log('发送撤单请求:', requestData)
    
    // 调用后端API
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/orders/cancel_by_id`, requestData)
    
    console.log('撤单响应:', response.data)
    
    if (response.data && response.data.success) {
      alert('撤单成功！')
      
      // 刷新挂单数据
      await fetchAllOrders()
    } else {
      throw new Error(response.data?.message || '撤单失败')
    }
  } catch (error) {
    console.error('撤单失败:', error)
    const errorMessage = error.response?.data?.message || error.message || '撤单失败'
    alert('撤单失败: ' + errorMessage)
  }
}

// 批量下单相关方法
function openBatchOrderModal() {
  showBatchOrderModal.value = true
  selectedUsers.value = []
  useAllUsers.value = false
  loadAvailableSymbols()
}

// 处理全部用户选择变化
function onAllUsersChange(checked) {
  if (checked) {
    selectedUsers.value = []
  }
  // 当取消全部用户选择时，保持selectedUsers不变，让用户手动选择
}

// 根据用户ID获取用户对象
function getUserById(userId) {
  return users.value.find(u => u.id === userId)
}

// 计算用户实际下单金额（基于可用余额和百分比）
function calculateUserOrderAmount(userId) {
  const user = getUserById(userId)
  if (!user || !user.availableBalance) return 0
  
  // 可用余额 × 百分比
  const amount = (user.availableBalance * batchOrderForm.value.positionPercentage) / 100
  return amount
}

async function loadAvailableSymbols() {
  try {
    symbolsLoading.value = true
    console.log('开始加载交易对列表...')
    
    const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/symbols/usdt`)
    console.log('交易对列表响应:', response.data)
    
    if (response.data && response.data.success && response.data.data) {
      const { symbols, symbols_detail } = response.data.data
      
      // 按字典序排序
      const sortedSymbols = symbols.sort()
      
      // 转换为选项格式
      availableSymbols.value = sortedSymbols.map(symbol => ({
        label: symbol,
        value: symbol
      }))
      
      console.log(`加载了 ${availableSymbols.value.length} 个交易对`)
    } else {
      console.warn('交易对数据格式不正确:', response.data)
      availableSymbols.value = []
    }
  } catch (error) {
    console.error('获取交易对列表失败:', error)
    availableSymbols.value = []
  } finally {
    symbolsLoading.value = false
  }
}

// 交易对搜索功能
async function onSymbolSearch(query) {
  if (!query || query.length < 2) {
    return
  }
  
  try {
    symbolsLoading.value = true
    console.log(`搜索交易对: ${query}`)
    
    const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/symbols/usdt`, {
      params: { search: query }
    })
    
    if (response.data && response.data.success && response.data.data) {
      const { symbols } = response.data.data
      
      // 按字典序排序
      const sortedSymbols = symbols.sort()
      
      // 转换为选项格式
      availableSymbols.value = sortedSymbols.map(symbol => ({
        label: symbol,
        value: symbol
      }))
      
      console.log(`搜索到 ${availableSymbols.value.length} 个匹配的交易对`)
    }
  } catch (error) {
    console.error('搜索交易对失败:', error)
  } finally {
    symbolsLoading.value = false
  }
}

async function onSymbolChange(symbol) {
  if (symbol) {
    try {
      // 查询该交易对的杠杆信息
      const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/leverage/symbol/${symbol}`)
      if (response.data && response.data.success) {
        const info = response.data.data
        
        // 更新杠杆限制
        maxLeverage.value = info.max_leverage || 1
        
        // 调整当前杠杆不超过最大值
        batchOrderForm.value.leverage = Math.min(batchOrderForm.value.leverage, maxLeverage.value)
        
        console.log(`${symbol} 杠杆信息:`, {
          symbol: info.symbol,
          maxLeverage: info.max_leverage,
          baseAsset: info.base_asset,
          quoteAsset: info.quote_asset,
          contractType: info.contract_type,
          status: info.status
        })
      }
    } catch (error) {
      console.error('获取杠杆信息失败:', error)
      // 重置为默认值
      maxLeverage.value = 1
    }
  }
}

async function submitBatchOrder() {
  if (!useAllUsers.value && selectedUsers.value.length === 0) {
    alert('请选择至少一个用户或选择全部用户')
    return
  }
  
  if (useAllUsers.value && users.value.length === 0) {
    alert('没有可用的用户')
    return
  }
  
  if (!batchOrderForm.value.symbol) {
    alert('请选择交易对')
    return
  }
  
  if (!batchOrderForm.value.positionPercentage || batchOrderForm.value.positionPercentage <= 0) {
    alert('请输入有效的仓位百分比')
    return
  }
  
  if (batchOrderForm.value.orderType === 'LIMIT' && (!batchOrderForm.value.price || batchOrderForm.value.price <= 0)) {
    alert('限价单必须设置价格')
    return
  }
  
  try {
    batchOrderLoading.value = true
    
    // 确定position_side
    const positionSide = batchOrderForm.value.side === 'BUY' ? 'LONG' : 'SHORT'
    
    // 计算每个用户的USDT金额
    let userIds, quantities
    if (useAllUsers.value) {
      // 全部用户：计算所有用户的金额
      userIds = users.value.map(user => user.id)
      quantities = users.value.map(user => {
        const amount = (user.availableBalance || 0) * batchOrderForm.value.positionPercentage / 100
        return Math.round(amount * 100) / 100
      })
    } else {
      // 部分用户：计算选中用户的金额
      userIds = selectedUsers.value
      quantities = selectedUsers.value.map(userId => {
        const amount = calculateUserOrderAmount(userId)
        return Math.round(amount * 100) / 100
      })
    }
    
    // 构建请求数据
    const requestData = {
      symbol: batchOrderForm.value.symbol,
      side: batchOrderForm.value.side,
      position_side: positionSide,
      user_ids: userIds,
      quantities: quantities,
      leverage: batchOrderForm.value.leverage,
      type: batchOrderForm.value.orderType,
      use_testnet: false
    }
    
    // 全部用户模式添加all_users字段
    if (useAllUsers.value) {
      requestData.all_users = true
    }
    
    // 添加限价单价格
    if (batchOrderForm.value.orderType === 'LIMIT' && batchOrderForm.value.price) {
      requestData.price = batchOrderForm.value.price.toString()
    }
    
    // 添加止盈止损价格
    if (batchOrderForm.value.takeProfitPrice) {
      requestData.take_profit_price = batchOrderForm.value.takeProfitPrice.toString()
    }
    if (batchOrderForm.value.stopLossPrice) {
      requestData.stop_loss_price = batchOrderForm.value.stopLossPrice.toString()
    }
    
    console.log('批量下单请求:', requestData)
    
    // 调用新的API接口
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/orders/batch_all`, requestData)
    
    console.log('批量下单响应:', response.data)
    
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
          successUsers.push({
            alias: result.alias,
            orderId: result.result?.orderId,
            status: result.result?.status,
            price: result.result?.price,
            executedQty: result.result?.executedQty
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
      let resultMessage = `批量下单完成！\n`
      resultMessage += `交易对: ${data.symbol}\n`
      resultMessage += `方向: ${data.side === 'BUY' ? '开多' : '开空'}\n`
      resultMessage += `仓位方向: ${data.position_side}\n`
      resultMessage += `杠杆: ${data.leverage}x\n`
      resultMessage += `USDT金额: ${data.quantity_usdt}\n`
      resultMessage += `目标用户数: ${data.target_count}\n`
      resultMessage += `成功: ${successCount}个，失败: ${failedCount}个\n\n`
      
      if (successUsers.length > 0) {
        resultMessage += '成功详情:\n'
        successUsers.forEach(user => {
          resultMessage += `• ${user.alias}:\n`
          resultMessage += `  订单ID: ${user.orderId}\n`
          resultMessage += `  状态: ${user.status}\n`
          resultMessage += `  价格: ${user.price}\n`
          resultMessage += `  已执行数量: ${user.executedQty}\n`
        })
      }
      
      if (failedUsers.length > 0) {
        resultMessage += '\n失败详情:\n'
        failedUsers.forEach(user => {
          resultMessage += `• ${user.alias}: ${user.error}\n`
        })
      }
      
      alert(resultMessage)
      
      // 关闭弹窗并刷新数据
      showBatchOrderModal.value = false
      await forceRefresh()
    } else {
      throw new Error(response.data?.message || '批量下单失败')
    }
    
  } catch (error) {
    console.error('批量下单失败:', error)
    alert('批量下单失败: ' + (error.response?.data?.message || error.message))
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

// 仓位操作按钮处理函数
function handleClosePosition(position) {
  console.log('市价平仓:', position)
  
  // 查找所有持有相同币种且方向一致的用户
  const affectedUsers = []
  users.value.forEach(user => {
    if (user.positions && user.positions.length > 0) {
      const matchingPosition = user.positions.find(p => 
        p.symbol === position.symbol && p.side === position.side
      )
      if (matchingPosition) {
        affectedUsers.push({
          id: user.id,
          alias: user.alias,
          position: matchingPosition
        })
      }
    }
  })
  
  // 设置弹窗数据
  closePositionModal.value = {
    show: true,
    symbol: position.symbol,
    side: position.side,
    percentage: 100,
    affectedUsers: affectedUsers,
    totalExpectedProfit: 0,
    loading: false
  }
  
  // 计算预计收益
  calculateExpectedProfit()
}

function handleTpSl(position) {
  console.log('止盈止损:', position)
  
  // 查找所有持有相同币种且方向一致的用户
  const affectedUsers = []
  users.value.forEach(user => {
    if (user.positions && user.positions.length > 0) {
      const matchingPosition = user.positions.find(p => 
        p.symbol === position.symbol && p.side === position.side
      )
      if (matchingPosition) {
        affectedUsers.push({
          id: user.id,
          alias: user.alias,
          position: matchingPosition,
          positions: user.positions, // 添加完整的positions数组
          expectedTpProfit: 0,
          expectedSlLoss: 0
        })
      }
    }
  })
  
  console.log('找到的受影响用户:', affectedUsers)
  
  // 设置弹窗数据
  tpSlModal.value = {
    show: true,
    symbol: position.symbol,
    side: position.side,
    closeRatio: 100,
    affectedUsers: affectedUsers,
    takeProfit: {
      enabled: false,
      price: null,
      closeRatio: 100
    },
    stopLoss: {
      enabled: false,
      price: null,
      closeRatio: 100
    },
    loading: false
  }
  
  console.log('设置的模态框数据:', tpSlModal.value)
  
  // 立即计算一次预计盈亏
  nextTick(() => {
    updateUserExpectedProfits()
  })
}

async function handleModifyLeverage(position) {
  console.log('修改杠杆:', position)
  
  // 查找所有持有相同币种且方向一致的用户
  const affectedUsers = []
  users.value.forEach(user => {
    if (user.positions && user.positions.length > 0) {
      const matchingPosition = user.positions.find(p => 
        p.symbol === position.symbol && p.side === position.side
      )
      if (matchingPosition) {
        affectedUsers.push({
          id: user.id,
          alias: user.alias,
          position: matchingPosition
        })
      }
    }
  })
  
  // 获取当前杠杆（取第一个用户的杠杆作为代表）
  const currentLeverage = affectedUsers.length > 0 ? affectedUsers[0].position.leverage : 0
  
  // 获取该交易对的最大杠杆
  let maxLeverageForSymbol = 1
  try {
    const response = await axios.get(`${import.meta.env.VITE_API_TRADE}/api/leverage/symbol/${position.symbol}`)
    if (response.data && response.data.success) {
      maxLeverageForSymbol = response.data.data.max_leverage || 1
    }
  } catch (error) {
    console.error('获取杠杆信息失败:', error)
    maxLeverageForSymbol = maxLeverage.value || 1
  }
  
  // 生成滑条标记
  const leverageMarks = {}
  const step = Math.max(1, Math.floor(maxLeverageForSymbol / 10))
  for (let i = 1; i <= maxLeverageForSymbol; i += step) {
    leverageMarks[i] = `${i}x`
  }
  // 确保最大值有标记
  if (maxLeverageForSymbol > 1) {
    leverageMarks[maxLeverageForSymbol] = `${maxLeverageForSymbol}x`
  }
  
  // 设置弹窗数据
  modifyLeverageModal.value = {
    show: true,
    symbol: position.symbol,
    side: position.side,
    currentLeverage: currentLeverage,
    newLeverage: Math.min(currentLeverage || 1, maxLeverageForSymbol),
    maxLeverage: maxLeverageForSymbol,
    affectedUsers: affectedUsers,
    leverageMarks: leverageMarks,
    loading: false
  }
}

// 获取用户当前实时盈亏
function getCurrentProfit(user) {
  const currentUser = users.value.find(u => u.id === user.id)
  if (currentUser && currentUser.positions) {
    const currentPosition = currentUser.positions.find(p => 
      p.symbol === closePositionModal.value.symbol && p.side === closePositionModal.value.side
    )
    return currentPosition ? currentPosition.unrealizedPnl : 0
  }
  return 0
}

// 计算预计收益
function calculateExpectedProfit() {
  const percentage = closePositionModal.value.percentage / 100
  let totalProfit = 0
  
  closePositionModal.value.affectedUsers.forEach(user => {
    // 直接从实时数据中获取当前盈亏，确保数据一致性
    const currentProfit = getCurrentProfit(user)
    const expectedProfit = currentProfit * percentage
    user.expectedProfit = expectedProfit
    totalProfit += expectedProfit
  })
  
  closePositionModal.value.totalExpectedProfit = totalProfit
}

// 更新杠杆信息
function updateLeverageInfo() {
  // 当选择新杠杆时，可以在这里添加额外的逻辑
  console.log('选择新杠杆:', modifyLeverageModal.value.newLeverage)
}

// 处理止盈checkbox变化
function handleTakeProfitChange(event) {
  console.log('止盈checkbox变化:', event.target.checked)
  tpSlModal.value.takeProfit.enabled = event.target.checked
  console.log('更新后止盈状态:', tpSlModal.value.takeProfit.enabled)
  // 强制更新
  nextTick(() => {
    updateTpSlCalculations()
  })
}

// 处理止损checkbox变化
function handleStopLossChange(event) {
  console.log('止损checkbox变化:', event.target.checked)
  tpSlModal.value.stopLoss.enabled = event.target.checked
  console.log('更新后止损状态:', tpSlModal.value.stopLoss.enabled)
  // 强制更新
  nextTick(() => {
    updateTpSlCalculations()
  })
}

// 格式化数值显示
function formatNumber(value) {
  if (isNaN(value) || value === null || value === undefined) {
    return '0.00'
  }
  return parseFloat(value).toFixed(2)
}

// 更新止盈止损计算
function updateTpSlCalculations() {
  console.log('止盈止损计算更新', {
    takeProfit: tpSlModal.value.takeProfit,
    stopLoss: tpSlModal.value.stopLoss
  })
  console.log('止盈enabled:', tpSlModal.value.takeProfit.enabled)
  console.log('止损enabled:', tpSlModal.value.stopLoss.enabled)
  updateUserExpectedProfits()
}


// 更新用户预计盈亏
function updateUserExpectedProfits() {
  console.log('=== 开始更新用户预计盈亏 ===')
  const modal = tpSlModal.value
  
  if (!modal || !modal.affectedUsers) {
    console.log('模态框或受影响用户数据不存在')
    return
  }
  
  console.log('开始更新用户预计盈亏，用户数量:', modal.affectedUsers.length)
  console.log('止盈设置:', modal.takeProfit)
  console.log('止损设置:', modal.stopLoss)
  console.log('模态框数据:', modal)
  
  modal.affectedUsers.forEach((user, index) => {
    console.log(`处理用户 ${index}:`, user)
    // 检查用户是否有positions数据
    if (!user.positions || !Array.isArray(user.positions)) {
      console.log('用户没有positions数据:', user)
      user.expectedTpProfit = 0
      user.expectedSlLoss = 0
      return
    }
    
    // 获取用户的仓位信息
    const userPosition = user.positions.find(p => 
      p.symbol === modal.symbol && p.side === modal.side
    )
    
    if (!userPosition) {
      user.expectedTpProfit = 0
      user.expectedSlLoss = 0
      return
    }
    
    const entryPrice = parseFloat(userPosition.entryPrice)
    const positionAmt = parseFloat(userPosition.amount) // 使用 amount 而不是 positionAmt
    const leverage = parseFloat(userPosition.leverage) || 1
    
    // 验证数值有效性
    if (isNaN(entryPrice) || isNaN(positionAmt) || entryPrice <= 0) {
      console.log('无效的仓位数据:', { entryPrice, positionAmt, userPosition })
      user.expectedTpProfit = 0
      user.expectedSlLoss = 0
      return
    }
    
    // 计算名义价值（持仓量 * 入场价）
    const notionalValue = Math.abs(positionAmt) * entryPrice
    // 计算实际保证金（名义价值 / 杠杆倍数）
    const margin = notionalValue / leverage
    
    console.log('计算数据:', {
      entryPrice,
      positionAmt,
      leverage,
      notionalValue,
      margin,
      side: userPosition.side,
      takeProfitEnabled: modal.takeProfit.enabled,
      takeProfitPrice: modal.takeProfit.price,
      stopLossEnabled: modal.stopLoss.enabled,
      stopLossPrice: modal.stopLoss.price
    })
    
    // 计算预计止盈
    if (modal.takeProfit.enabled && modal.takeProfit.price && modal.takeProfit.price > 0) {
      const tpPrice = parseFloat(modal.takeProfit.price)
      const tpCloseRatio = (modal.takeProfit.closeRatio || 100) / 100
      
      if (isNaN(tpPrice) || tpPrice <= 0) {
        user.expectedTpProfit = 0
      } else {
        let priceDiff, priceDiffRatio
        
        if (userPosition.side === 'LONG') {
          // 多头：价格上涨为盈利
          priceDiff = tpPrice - entryPrice
          priceDiffRatio = priceDiff / entryPrice
        } else {
          // 空头：价格下跌为盈利
          priceDiff = entryPrice - tpPrice
          priceDiffRatio = priceDiff / entryPrice
        }
        
        // 杠杆交易收益计算：
        // 收益 = 保证金 * 价格变化比例 * 杠杆倍数 * 平仓比例
        const expectedProfit = margin * priceDiffRatio * leverage * tpCloseRatio
        
        console.log('止盈计算:', {
          tpPrice,
          entryPrice,
          priceDiff,
          priceDiffRatio,
          margin,
          leverage,
          tpCloseRatio,
          expectedProfit,
          side: userPosition.side
        })
        
        user.expectedTpProfit = isNaN(expectedProfit) ? 0 : expectedProfit
      }
    } else {
      user.expectedTpProfit = 0
    }
    
    // 计算预计止损
    if (modal.stopLoss.enabled && modal.stopLoss.price && modal.stopLoss.price > 0) {
      const slPrice = parseFloat(modal.stopLoss.price)
      const slCloseRatio = (modal.stopLoss.closeRatio || 100) / 100
      
      if (isNaN(slPrice) || slPrice <= 0) {
        user.expectedSlLoss = 0
      } else {
        let priceDiff, priceDiffRatio
        
        if (userPosition.side === 'LONG') {
          // 多头：止损价格低于入场价为亏损，高于入场价为盈利
          priceDiff = slPrice - entryPrice  // 止损价 - 入场价
          priceDiffRatio = priceDiff / entryPrice
        } else {
          // 空头：止损价格高于入场价为亏损，低于入场价为盈利
          priceDiff = entryPrice - slPrice  // 入场价 - 止损价
          priceDiffRatio = priceDiff / entryPrice
        }
        
        // 杠杆交易亏损计算：
        // 亏损 = 保证金 * 价格变化比例 * 杠杆倍数 * 平仓比例
        const expectedLoss = margin * priceDiffRatio * leverage * slCloseRatio
        
        console.log('止损计算:', {
          slPrice,
          entryPrice,
          priceDiff,
          priceDiffRatio,
          margin,
          leverage,
          slCloseRatio,
          expectedLoss,
          side: userPosition.side,
          interpretation: expectedLoss > 0 ? '止损后盈利' : expectedLoss < 0 ? '止损后亏损' : '止损后无盈亏'
        })
        
        user.expectedSlLoss = isNaN(expectedLoss) ? 0 : expectedLoss
      }
    } else {
      user.expectedSlLoss = 0
    }
    
    console.log(`用户 ${index} 最终结果:`, {
      expectedTpProfit: user.expectedTpProfit,
      expectedSlLoss: user.expectedSlLoss
    })
  })
  
  console.log('=== 用户预计盈亏更新完成 ===')
}

// 确认止盈止损设置
async function confirmTpSl() {
  try {
    tpSlModal.value.loading = true
    
    // 准备API请求参数
    const requestData = {
      symbol: tpSlModal.value.symbol,
      position_side: tpSlModal.value.side,
      user_orders: {},
      use_testnet: false
    }
    
    // 为每个用户计算平仓量
    tpSlModal.value.affectedUsers.forEach(user => {
      const userOrder = {}
      
      // 计算止盈平仓量（USDT金额）
      if (tpSlModal.value.takeProfit.enabled && tpSlModal.value.takeProfit.price) {
        const takeProfitPrice = parseFloat(tpSlModal.value.takeProfit.price)
        const takeProfitRatio = (tpSlModal.value.takeProfit.closeRatio || 100) / 100
        
        // 计算当前仓位价值（USDT）
        const currentPositionValue = Math.abs(user.position.amount) * user.position.entryPrice
        const takeProfitAmount = currentPositionValue * takeProfitRatio
        
        userOrder.take_profit_price = takeProfitPrice
        userOrder.take_profit_amount = takeProfitAmount
      }
      
      // 计算止损平仓量（USDT金额）
      if (tpSlModal.value.stopLoss.enabled && tpSlModal.value.stopLoss.price) {
        const stopLossPrice = parseFloat(tpSlModal.value.stopLoss.price)
        const stopLossRatio = (tpSlModal.value.stopLoss.closeRatio || 100) / 100
        
        // 计算当前仓位价值（USDT）
        const currentPositionValue = Math.abs(user.position.amount) * user.position.entryPrice
        const stopLossAmount = currentPositionValue * stopLossRatio
        
        userOrder.stop_loss_price = stopLossPrice
        userOrder.stop_loss_amount = stopLossAmount
      }
      
      // 只有当用户有止盈或止损设置时才添加到请求中
      if (Object.keys(userOrder).length > 0) {
        requestData.user_orders[user.id] = userOrder
      }
    })
    
    console.log('发送止盈止损请求:', requestData)
    
    // 调用后端API
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/positions/tp-sl`, requestData)
    
    console.log('止盈止损响应:', response.data)
    
    if (response.data && response.data.success) {
      const data = response.data.data
      
      // 显示成功信息
      let successMessage = `止盈止损设置成功！\n`
      successMessage += `交易对: ${tpSlModal.value.symbol}\n`
      successMessage += `仓位方向: ${tpSlModal.value.side}\n`
      successMessage += `成功设置用户数: ${data.results.length}\n\n`
      
      // 显示每个用户的设置结果
      data.results.forEach((result, index) => {
        successMessage += `用户${index + 1} (${result.alias}):\n`
        if (result.take_profit_price) {
          successMessage += `  止盈: $${result.take_profit_price} (${result.take_profit_amount} USDT, ${result.take_profit_quantity} ${tpSlModal.value.symbol.replace('USDT', '')})\n`
        }
        if (result.stop_loss_price) {
          successMessage += `  止损: $${result.stop_loss_price} (${result.stop_loss_amount} USDT, ${result.stop_loss_quantity} ${tpSlModal.value.symbol.replace('USDT', '')})\n`
        }
        successMessage += `  当前价格: $${result.current_price}\n`
        successMessage += `  状态: ${result.success ? '成功' : '失败'}\n`
        if (result.orders && result.orders.length > 0) {
          successMessage += `  订单数: ${result.orders.length}\n`
        }
        successMessage += '\n'
      })
      
      alert(successMessage)
      
      // 关闭弹窗
      tpSlModal.value.show = false
      
      // 刷新仓位数据
      await fetchAllPositions()
    } else {
      throw new Error(response.data?.message || '设置止盈止损失败')
    }
    
  } catch (error) {
    console.error('设置止盈止损失败:', error)
    const errorMessage = error.response?.data?.message || error.message || '设置止盈止损失败'
    alert('设置止盈止损失败: ' + errorMessage)
  } finally {
    tpSlModal.value.loading = false
  }
}

// 确认修改杠杆
async function confirmModifyLeverage() {
  try {
    modifyLeverageModal.value.loading = true
    
    // 构建请求数据
    const requestData = {
      symbol: modifyLeverageModal.value.symbol,
      position_side: modifyLeverageModal.value.side,
      new_leverage: modifyLeverageModal.value.newLeverage,
      use_testnet: false
    }
    
    console.log('发送修改杠杆请求:', requestData)
    
    // 调用后端API修改杠杆
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/leverage/modify`, requestData)
    
    if (response.data && response.data.success) {
      const result = response.data.data
      console.log('修改杠杆结果:', result)
      
      // 显示成功信息
      const successMessage = `杠杆修改完成！\n\n` +
        `📊 交易对: ${result.symbol}\n` +
        `📈 方向: ${result.position_side === 'LONG' ? '多头' : '空头'}\n` +
        `⚡ 新杠杆: ${result.new_leverage}x\n\n` +
        `👥 用户统计:\n` +
        `   • 总用户数: ${result.total_users}\n` +
        `   • 有仓位的用户: ${result.users_with_position}\n` +
        `   • 成功修改: ${result.successful_modifications}\n` +
        `   • 失败: ${result.failed_modifications}`
      
      alert(successMessage)
      
      // 关闭弹窗
      modifyLeverageModal.value.show = false
      
      // 刷新数据
      await forceRefresh()
    } else {
      throw new Error(response.data?.message || '修改杠杆请求失败')
    }
    
  } catch (error) {
    console.error('修改杠杆失败:', error)
    const errorMessage = error.response?.data?.message || error.message || '修改杠杆失败'
    alert('修改杠杆失败: ' + errorMessage)
  } finally {
    modifyLeverageModal.value.loading = false
  }
}

// 确认平仓
async function confirmClosePosition() {
  try {
    closePositionModal.value.loading = true
    
    // 构建请求数据
    const requestData = {
      symbol: closePositionModal.value.symbol,
      position_side: closePositionModal.value.side,
      close_ratio: closePositionModal.value.percentage,
      use_testnet: false
    }
    
    console.log('发送平仓请求:', requestData)
    
    // 调用后端API进行平仓
    const response = await axios.post(`${import.meta.env.VITE_API_TRADE}/api/positions/market-close`, requestData)
    
    if (response.data && response.data.success) {
      const result = response.data.data
      console.log('平仓结果:', result)
      
      // 显示成功信息
      const successMessage = `平仓完成！\n\n` +
        `📊 交易对: ${result.symbol}\n` +
        `📈 方向: ${result.position_side === 'LONG' ? '多头' : '空头'}\n` +
        `📉 平仓比例: ${result.close_ratio}%\n\n` +
        `👥 用户统计:\n` +
        `   • 总用户数: ${result.total_users}\n` +
        `   • 有仓位的用户: ${result.users_with_position}\n` +
        `   • 成功平仓: ${result.successful_closes}\n` +
        `   • 失败: ${result.failed_closes}`
      
      alert(successMessage)
      
      // 关闭弹窗
      closePositionModal.value.show = false
      
      // 刷新数据
      await forceRefresh()
    } else {
      throw new Error(response.data?.message || '平仓请求失败')
    }
    
  } catch (error) {
    console.error('平仓失败:', error)
    const errorMessage = error.response?.data?.message || error.message || '平仓失败'
    alert('平仓失败: ' + errorMessage)
  } finally {
    closePositionModal.value.loading = false
  }
}

// 组件卸载时清理定时器
onUnmounted(() => {
  stopAutoRefresh()
  stopHeartbeat()
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

// 监听平仓百分比变化
watch(() => closePositionModal.value.percentage, () => {
  if (closePositionModal.value.show) {
    calculateExpectedProfit()
  }
})

// 监听用户数据变化，实时更新预计收益
watch(() => users.value, () => {
  if (closePositionModal.value.show) {
    calculateExpectedProfit()
  }
}, { deep: true })

// 监听止盈止损价格变化
watch(() => tpSlModal.value.takeProfit.price, () => {
  if (tpSlModal.value.show) {
    updateTpSlCalculations()
  }
})

watch(() => tpSlModal.value.stopLoss.price, () => {
  if (tpSlModal.value.show) {
    updateTpSlCalculations()
  }
})

watch(() => tpSlModal.value.takeProfit.closeRatio, () => {
  if (tpSlModal.value.show) {
    updateTpSlCalculations()
  }
})

watch(() => tpSlModal.value.stopLoss.closeRatio, () => {
  if (tpSlModal.value.show) {
    updateTpSlCalculations()
  }
})

// 监听止盈止损开关变化
watch(() => tpSlModal.value.takeProfit.enabled, () => {
  if (tpSlModal.value.show) {
    updateTpSlCalculations()
  }
})

watch(() => tpSlModal.value.stopLoss.enabled, () => {
  if (tpSlModal.value.show) {
    updateTpSlCalculations()
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
  gap: 12px;
  padding: 16px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  transition: all 0.2s ease;
}

.order-item:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
  transform: translateY(-1px);
}

.position-info,
.order-info {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: space-between;
}

.position-left {
  display: flex;
  align-items: center;
  gap: 8px;
}

.liquidation-price {
  color: #ff6b35;
  font-size: 12px;
  font-weight: 600;
  background: rgba(255, 107, 53, 0.1);
  padding: 2px 8px;
  border-radius: 4px;
  border: 1px solid rgba(255, 107, 53, 0.3);
  white-space: nowrap;
}

.liquidation-price.no-liquidation {
  color: #999;
  background: rgba(153, 153, 153, 0.1);
  border: 1px solid rgba(153, 153, 153, 0.3);
}

.leverage-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 32px;
  height: 20px;
  padding: 0 8px;
  font-size: 11px;
  font-weight: 700;
  color: #fff;
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
  border-radius: 10px;
  box-shadow: 0 2px 4px rgba(255, 107, 107, 0.3);
  border: 1px solid rgba(255, 107, 107, 0.2);
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
  letter-spacing: 0.3px;
  transition: all 0.2s ease;
}

.leverage-badge:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(255, 107, 107, 0.4);
}

.position-item {
  margin-bottom: 16px;
  padding: 16px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  transition: all 0.2s ease;
}

.position-item:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
  transform: translateY(-1px);
}

.position-actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid var(--n-border-color);
  justify-content: flex-start;
}

.action-btn {
  flex: 1;
  min-width: 80px;
  height: 32px;
  font-size: 12px;
  font-weight: 600;
  border-radius: 6px;
  transition: all 0.2s ease;
  border: none;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.action-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.close-btn {
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
  color: white;
}

.close-btn:hover {
  background: linear-gradient(135deg, #ff5252 0%, #d63031 100%);
}

.tp-sl-btn {
  background: linear-gradient(135deg, #fdcb6e 0%, #e17055 100%);
  color: white;
}

.tp-sl-btn:hover {
  background: linear-gradient(135deg, #f39c12 0%, #d63031 100%);
}

.leverage-btn {
  background: linear-gradient(135deg, #74b9ff 0%, #0984e3 100%);
  color: white;
}

.leverage-btn:hover {
  background: linear-gradient(135deg, #0984e3 0%, #2d3436 100%);
}

/* 市价平仓弹窗样式 */
.close-position-form {
  padding: 16px 0;
}

.close-info {
  margin-bottom: 24px;
  text-align: center;
}

.close-info h4 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--n-text-color);
}

.info-text {
  margin: 0;
  color: var(--n-text-color-2);
  font-size: 14px;
}

.percentage-slider {
  margin-bottom: 24px;
}

.users-list {
  margin-bottom: 24px;
}

.users-list h5 {
  margin: 0 0 12px 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--n-text-color);
}

.users-container {
  max-height: 200px;
  overflow-y: auto;
  border: 1px solid var(--n-border-color);
  border-radius: 8px;
  padding: 8px;
}

.user-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  margin-bottom: 4px;
  background: var(--n-card-color);
  border-radius: 6px;
  border: 1px solid var(--n-border-color);
}

.user-item:last-child {
  margin-bottom: 0;
}

.user-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.user-name {
  font-weight: 600;
  color: var(--n-text-color);
  font-size: 14px;
}

.position-info {
  font-size: 12px;
  color: var(--n-text-color-2);
}

.profit-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  text-align: right;
}

.current-profit,
.expected-profit {
  font-size: 12px;
  font-weight: 500;
}

.positive {
  color: #00b894;
}

.negative {
  color: #e17055;
}

.total-info {
  display: flex;
  justify-content: space-between;
  padding: 16px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 8px;
  margin-bottom: 16px;
}

.total-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.total-item .label {
  font-size: 12px;
  color: var(--n-text-color-2);
}

.total-item .value {
  font-size: 16px;
  font-weight: 600;
  color: var(--n-text-color);
}

.modal-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
}

/* 修改杠杆弹窗样式 */
.modify-leverage-form {
  padding: 16px 0;
}

.leverage-info {
  margin-bottom: 24px;
  text-align: center;
  width: 100%;
  display: block !important;
}

.title-main {
  margin: 0 0 4px 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--n-text-color);
  display: block !important;
  line-height: 1.2;
  width: 100%;
}

.title-sub {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 500;
  color: var(--n-color-primary);
  display: block !important;
  line-height: 1.2;
  width: 100%;
}

.leverage-selector {
  margin-bottom: 24px;
  padding: 20px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.leverage-info .current-leverage,
.leverage-info .new-leverage {
  font-size: 12px;
  font-weight: 500;
  color: var(--n-text-color-2);
}

.leverage-info .new-leverage {
  color: var(--n-color-primary);
  font-weight: 600;
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
  transition: all 0.3s ease;
}

.pnl-value.highlight,
.pnl-percentage.highlight {
  background: #fbbf24;
  color: #92400e;
  padding: 2px 6px;
  border-radius: 4px;
  animation: highlightPulse 1s ease-in-out;
}

@keyframes highlightPulse {
  0% {
    background: #fbbf24;
    transform: scale(1);
  }
  50% {
    background: #f59e0b;
    transform: scale(1.05);
  }
  100% {
    background: #fbbf24;
    transform: scale(1);
  }
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
  font-weight: 700;
  font-size: 14px;
  color: #1a1a1a;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  letter-spacing: 0.5px;
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

.loading-text {
  color: #666;
  font-size: 12px;
  margin-top: 4px;
  text-align: center;
}

/* 新的挂单UI样式 */
.order-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.order-type-badge {
  display: flex;
  align-items: center;
  gap: 8px;
}

.order-type {
  font-size: 12px;
  font-weight: 600;
  padding: 4px 8px;
  border-radius: 6px;
  color: white;
}

.order-type.limit {
  background: #2196f3;
}

.order-type.market {
  background: #4caf50;
}

.order-type.stop-market {
  background: #ff9800;
}

.order-type.take-profit-market {
  background: #9c27b0;
}

.order-type.stop-loss-limit {
  background: #f44336;
}

.order-type.take-profit-limit {
  background: #673ab7;
}

.order-type.default {
  background: var(--n-color-primary);
}

.reduce-only-flag {
  font-size: 11px;
  font-weight: 500;
  padding: 2px 6px;
  border-radius: 4px;
  background: #ff6b6b;
  color: white;
}

.order-time {
  font-size: 12px;
  color: var(--n-text-color-2);
  font-family: monospace;
}

.order-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}

.order-main-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}

.symbol-side {
  display: flex;
  align-items: center;
  gap: 8px;
}

.trigger-price {
  display: flex;
  align-items: center;
  gap: 8px;
}

.price-label {
  font-size: 12px;
  color: var(--n-text-color-2);
  font-weight: 500;
}

.price-value {
  font-size: 14px;
  font-weight: 600;
  color: var(--n-color-primary);
  font-family: monospace;
}

.quantity-info {
  display: flex;
  gap: 16px;
}

.quantity-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.qty-label {
  font-size: 12px;
  color: var(--n-text-color-2);
  font-weight: 500;
}

.qty-value {
  font-size: 13px;
  font-weight: 600;
  color: var(--n-text-color);
  font-family: monospace;
}

.order-status {
  display: flex;
  align-items: center;
}

.status-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 4px 8px;
  border-radius: 6px;
  text-transform: uppercase;
}

.status-badge.new {
  background: #e3f2fd;
  color: #1976d2;
}

.status-badge.partially_filled {
  background: #fff3e0;
  color: #f57c00;
}

.status-badge.filled {
  background: #e8f5e8;
  color: #2e7d32;
}

.status-badge.canceled {
  background: #ffebee;
  color: #d32f2f;
}

/* 撤单按钮样式 */
.order-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid var(--n-border-color);
}

.cancel-order-btn {
  font-size: 12px;
  height: 28px;
  padding: 0 12px;
  border-radius: 6px;
  font-weight: 500;
}

.batch-cancel-btn {
  font-size: 12px;
  height: 28px;
  padding: 0 12px;
  border-radius: 6px;
  font-weight: 500;
}

/* 头部操作按钮样式 */
.header-actions {
  display: flex;
  gap: 8px;
  align-items: center;
}

.cancel-all-btn {
  font-size: 12px;
  height: 28px;
  padding: 0 12px;
  border-radius: 6px;
  font-weight: 500;
}

.cancel-order-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 止盈止损弹窗样式 */
.tpsl-form {
  padding: 16px 0;
}

.tpsl-info {
  margin-bottom: 24px;
  text-align: center;
}

.tpsl-info h4 {
  margin: 0 0 4px 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--n-text-color);
  display: block !important;
  line-height: 1.2;
  width: 100%;
}

.tpsl-info h5 {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 500;
  color: var(--n-color-primary);
  display: block !important;
  line-height: 1.2;
  width: 100%;
}

.tpsl-section {
  margin-bottom: 24px;
  padding: 16px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.section-header {
  margin-bottom: 16px;
  cursor: pointer;
  user-select: none;
  position: relative;
  z-index: 1;
}

.section-header .n-checkbox {
  width: 100%;
  cursor: pointer;
  pointer-events: auto !important;
  position: relative;
  z-index: 2;
}

.checkbox-label {
  display: flex;
  align-items: center;
  cursor: pointer;
  width: 100%;
  user-select: none;
}

.checkbox-label input[type="checkbox"] {
  cursor: pointer;
  pointer-events: auto;
  width: 16px;
  height: 16px;
  margin-right: 8px;
  accent-color: #18a058;
  appearance: none;
  border: 2px solid #d9d9d9;
  border-radius: 3px;
  background: white;
  position: relative;
}

.checkbox-label input[type="checkbox"]:checked {
  background: #18a058;
  border-color: #18a058;
}

.checkbox-label input[type="checkbox"]:checked::after {
  content: '✓';
  position: absolute;
  top: -2px;
  left: 2px;
  color: white;
  font-size: 12px;
  font-weight: bold;
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--n-text-color);
}

.section-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}


.calculated-price {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--n-color-primary);
  color: white;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 600;
}

.close-ratio-section {
  margin-bottom: 24px;
  padding: 16px;
  background: var(--n-card-color);
  border: 1px solid var(--n-border-color);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.expected-loss {
  font-size: 12px;
  font-weight: 500;
}

.order-details {
  font-size: 12px;
  color: var(--n-text-color-2);
  font-family: monospace;
}

.form-tip {
  font-size: 12px;
  color: var(--n-text-color-3);
  margin-left: 8px;
}
</style>
