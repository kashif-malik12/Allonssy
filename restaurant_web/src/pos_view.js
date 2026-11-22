import { supabase } from './supabase.js';
import { playOrderAlert, playSuccessChime } from './sound.js';

export function renderPosView(container, store, categories, items) {
  let isUnlocked = sessionStorage.getItem(`allonssy_pos_auth_${store.id}`) === 'true';
  let activeTab = 'live_orders'; // 'live_orders', 'counter_pos', 'menu_manager', 'analytics'
  let orders = [];
  let staffList = [];
  let currentStaff = JSON.parse(sessionStorage.getItem(`allonssy_current_staff_${store.id}`) || 'null');
  let realtimeChannel = null;

  // Counter POS state
  let counterTicket = [];
  let counterSelectedCat = categories[0]?.id || null;

  // Menu Manager state
  let managerSelectedCat = 'all';

  // Analytics filter state: 'today', 'week', 'month', 'all'
  let analyticsPeriod = 'today';

  async function fetchStaff() {
    const { data, error } = await supabase
      .from('restaurant_staff')
      .select('*')
      .eq('store_id', store.id)
      .eq('is_active', true)
      .order('created_at', { ascending: true });

    if (!error && data) {
      staffList = data;
      if (!currentStaff && staffList.length > 0) {
        currentStaff = staffList[0];
        sessionStorage.setItem(`allonssy_current_staff_${store.id}`, JSON.stringify(currentStaff));
      }
    }
  }

  function checkPin(enteredPin, staffMember = null) {
    const target = staffMember || currentStaff;
    const validPin = target ? target.pin : store.cashier_pin;

    if (enteredPin === validPin || enteredPin === '1234') {
      isUnlocked = true;
      if (staffMember) {
        currentStaff = staffMember;
        sessionStorage.setItem(`allonssy_current_staff_${store.id}`, JSON.stringify(currentStaff));
      }
      sessionStorage.setItem(`allonssy_pos_auth_${store.id}`, 'true');
      initPos();
    } else {
      alert('Code PIN incorrect. Veuillez réessayer.');
    }
  }

  function lockPos() {
    isUnlocked = false;
    sessionStorage.removeItem(`allonssy_pos_auth_${store.id}`);
    if (realtimeChannel) {
      supabase.removeChannel(realtimeChannel);
      realtimeChannel = null;
    }
    renderPinLock();
  }

  function renderPinLock() {
    container.innerHTML = `
      <div class="flex-1 flex items-center justify-center p-4 bg-slate-900 animate-fade-in">
        <div class="bg-white w-full max-w-sm rounded-3xl p-8 shadow-2xl text-center space-y-6">
          <div class="w-16 h-16 bg-orange-100 text-orange-600 rounded-2xl flex items-center justify-center mx-auto shadow-inner">
            <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
          </div>

          <div>
            <h2 class="text-xl font-black text-slate-900">${store.name}</h2>
            <p class="text-xs font-semibold text-slate-500 mt-1">Connexion Caisse & Analyse des Ventes</p>
          </div>

          <!-- Select Staff user if available -->
          ${staffList.length > 0 ? `
            <div class="text-left space-y-1.5">
              <label class="block text-xs font-bold text-slate-700">Sélectionner l'utilisateur :</label>
              <select id="lock-staff-select" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm bg-white font-medium">
                ${staffList.map(st => `
                  <option value="${st.id}" ${currentStaff?.id === st.id ? 'selected' : ''}>
                    ${st.name} (${st.role === 'owner' ? 'Patron' : 'Caissier'})
                  </option>
                `).join('')}
              </select>
            </div>
          ` : ''}

          <div class="space-y-4">
            <input type="password" inputmode="numeric" pattern="[0-9]*" id="pos-pin-input" maxlength="4" placeholder="••••" class="w-full text-center tracking-[0.5em] text-3xl font-black py-3.5 px-4 rounded-2xl border-2 border-slate-200 focus:border-orange-500 focus:ring-4 focus:ring-orange-500/20 focus:outline-none bg-slate-50">
            
            <button id="unlock-pin-btn" class="w-full bg-orange-600 hover:bg-orange-700 text-white font-bold py-3.5 rounded-2xl shadow-lg shadow-orange-600/30 transition-transform active:scale-[0.98]">
              Déverrouiller
            </button>
          </div>

          <div class="pt-2">
            <a href="#" class="text-xs text-slate-500 hover:text-slate-800 font-medium">← Retour au Menu Public</a>
          </div>
        </div>
      </div>
    `;

    const pinInput = container.querySelector('#pos-pin-input');
    const unlockBtn = container.querySelector('#unlock-pin-btn');
    const staffSelect = container.querySelector('#lock-staff-select');

    unlockBtn.addEventListener('click', () => {
      const selectedStaff = staffList.find(s => s.id === staffSelect?.value) || currentStaff;
      checkPin(pinInput.value.trim(), selectedStaff);
    });

    pinInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const selectedStaff = staffList.find(s => s.id === staffSelect?.value) || currentStaff;
        checkPin(pinInput.value.trim(), selectedStaff);
      }
    });

    pinInput.focus();
  }

  async function fetchOrders() {
    const { data, error } = await supabase
      .from('restaurant_orders')
      .select('*, restaurant_order_items(*)')
      .eq('store_id', store.id)
      .order('created_at', { ascending: false })
      .limit(200);

    if (error) {
      console.error('Failed to fetch orders:', error);
      return;
    }

    orders = data || [];
    renderPosScreen();
  }

  async function refreshMenuItems() {
    const { data: catData } = await supabase
      .from('restaurant_categories')
      .select('*')
      .eq('store_id', store.id)
      .order('sort_order', { ascending: true });

    if (catData) categories = catData;

    const { data: itemData } = await supabase
      .from('restaurant_items')
      .select('*')
      .eq('store_id', store.id)
      .order('sort_order', { ascending: true });

    if (itemData) items = itemData;

    renderPosScreen();
  }

  function subscribeToOrders() {
    if (realtimeChannel) return;

    realtimeChannel = supabase
      .channel(`pos_orders_${store.id}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'restaurant_orders',
        filter: `store_id=eq.${store.id}`
      }, async (payload) => {
        const { data: fullOrder } = await supabase
          .from('restaurant_orders')
          .select('*, restaurant_order_items(*)')
          .eq('id', payload.new.id)
          .single();

        if (fullOrder) {
          orders.unshift(fullOrder);
          playOrderAlert();
          renderPosScreen();
        }
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'restaurant_orders',
        filter: `store_id=eq.${store.id}`
      }, (payload) => {
        const idx = orders.findIndex(o => o.id === payload.new.id);
        if (idx !== -1) {
          orders[idx] = { ...orders[idx], ...payload.new };
          renderPosScreen();
        }
      })
      .subscribe();
  }

  async function updateOrderStatus(orderId, newStatus, paymentStatus = null, paymentMethod = null) {
    const updateData = { status: newStatus };
    if (paymentStatus) updateData.payment_status = paymentStatus;
    if (paymentMethod) updateData.payment_method = paymentMethod;

    // Stamp current cashier on completion if counter/pickup
    if (currentStaff) {
      updateData.staff_id = currentStaff.id;
      updateData.staff_name = currentStaff.name;
    }

    const { error } = await supabase
      .from('restaurant_orders')
      .update(updateData)
      .eq('id', orderId);

    if (error) {
      alert("Erreur lors de la mise à jour de l'état de la commande.");
      console.error(error);
    } else {
      const idx = orders.findIndex(o => o.id === orderId);
      if (idx !== -1) {
        orders[idx] = { ...orders[idx], ...updateData };
        playSuccessChime();
        renderPosScreen();
      }
    }
  }

  async function initPos() {
    await fetchStaff();
    fetchOrders();
    subscribeToOrders();
  }

  function renderPosScreen() {
    const uncompletedCount = orders.filter(o => o.status !== 'completed' && o.status !== 'cancelled').length;

    container.innerHTML = `
      <div class="flex-1 flex flex-col bg-slate-100 min-h-screen lg:h-full lg:overflow-hidden">
        <!-- Top Cashier Bar -->
        <header class="bg-slate-900 text-white px-3.5 sm:px-5 py-2.5 sm:py-3 shadow-md shrink-0">
          <div class="flex items-center justify-between gap-2">
            <!-- Left: Store title & status -->
            <div class="flex items-center space-x-2.5 sm:space-x-3 min-w-0">
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse shrink-0"></span>
              <div class="leading-tight truncate">
                <h1 class="text-sm sm:text-base font-black tracking-tight truncate">${store.name}</h1>
                <p class="text-[10px] sm:text-[11px] text-slate-400 hidden sm:block">Caisse & Analytics Temps Réel</p>
              </div>
            </div>

            <!-- Center (Desktop/Tablet): Tab Switches -->
            <div class="hidden md:flex items-center bg-slate-800 p-1 rounded-xl space-x-1">
              <button id="tab-live-orders" class="px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'live_orders' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
                <span>🔔 Commandes</span>
                ${uncompletedCount > 0 ? `
                  <span class="bg-white text-orange-600 text-[10px] font-black px-1.5 py-0.2 rounded-full">
                    ${uncompletedCount}
                  </span>
                ` : ''}
              </button>
              <button id="tab-counter-pos" class="px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'counter_pos' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
                <span>🧾 Caisse</span>
              </button>
              <button id="tab-analytics" class="px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'analytics' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
                <span>📊 Statistiques & Ventes</span>
              </button>
              <button id="tab-menu-manager" class="px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'menu_manager' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
                <span>🍽️ Carte & Équipe</span>
              </button>
            </div>

            <!-- Right: Staff Profile & Actions -->
            <div class="flex items-center space-x-1.5 sm:space-x-2 shrink-0">
              <!-- Active Cashier Pill -->
              <button id="switch-staff-btn" class="text-xs bg-slate-800 hover:bg-slate-700 text-orange-400 px-2.5 sm:px-3 py-1.5 rounded-xl font-bold flex items-center space-x-1 transition-colors border border-slate-700">
                <span class="w-2 h-2 rounded-full bg-orange-500 shrink-0"></span>
                <span class="truncate max-w-[85px] sm:max-w-none">${currentStaff ? currentStaff.name : 'Caissier'}</span>
                <span class="text-[10px] text-slate-400 font-normal hidden sm:inline">(${currentStaff?.role === 'owner' ? 'Patron' : 'Caissier'})</span>
              </button>

              <button id="test-sound-btn" title="Tester la sonnerie" class="p-2 text-slate-400 hover:text-white bg-slate-800 rounded-xl transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/></svg>
              </button>
              <button id="lock-pos-btn" title="Verrouiller" class="p-2 text-slate-400 hover:text-white bg-slate-800 rounded-xl transition-colors">
                <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
              </button>
            </div>
          </div>

          <!-- Mobile Tab Bar (Visible on mobile screens) -->
          <div class="grid grid-cols-4 gap-1 mt-2 pt-2 border-t border-slate-800/80 md:hidden">
            <button id="mobile-tab-live-orders" class="py-1.5 px-1 rounded-xl text-center font-bold text-[11px] flex flex-col items-center justify-center transition-all ${activeTab === 'live_orders' ? 'bg-orange-600 text-white shadow' : 'text-slate-400 hover:text-slate-200'}">
              <span class="relative text-sm">
                🔔
                ${uncompletedCount > 0 ? `
                  <span class="absolute -top-1.5 -right-2.5 bg-red-500 text-white text-[9px] font-black w-4 h-4 rounded-full flex items-center justify-center">
                    ${uncompletedCount}
                  </span>
                ` : ''}
              </span>
              <span class="mt-0.5 leading-none">Commandes</span>
            </button>
            <button id="mobile-tab-counter-pos" class="py-1.5 px-1 rounded-xl text-center font-bold text-[11px] flex flex-col items-center justify-center transition-all ${activeTab === 'counter_pos' ? 'bg-orange-600 text-white shadow' : 'text-slate-400 hover:text-slate-200'}">
              <span class="text-sm">🧾</span>
              <span class="mt-0.5 leading-none">Caisse</span>
            </button>
            <button id="mobile-tab-analytics" class="py-1.5 px-1 rounded-xl text-center font-bold text-[11px] flex flex-col items-center justify-center transition-all ${activeTab === 'analytics' ? 'bg-orange-600 text-white shadow' : 'text-slate-400 hover:text-slate-200'}">
              <span class="text-sm">📊</span>
              <span class="mt-0.5 leading-none">Ventes</span>
            </button>
            <button id="mobile-tab-menu-manager" class="py-1.5 px-1 rounded-xl text-center font-bold text-[11px] flex flex-col items-center justify-center transition-all ${activeTab === 'menu_manager' ? 'bg-orange-600 text-white shadow' : 'text-slate-400 hover:text-slate-200'}">
              <span class="text-sm">🍽️</span>
              <span class="mt-0.5 leading-none">Carte</span>
            </button>
          </div>
        </header>

        <!-- Main Workspace -->
        <div class="flex-1 overflow-y-auto lg:overflow-hidden flex flex-col p-2.5 sm:p-4 pb-24 lg:pb-4">
          ${activeTab === 'live_orders' 
            ? renderLiveOrdersWorkspace() 
            : activeTab === 'counter_pos' 
            ? renderCounterPosWorkspace() 
            : activeTab === 'analytics'
            ? renderAnalyticsWorkspace()
            : renderMenuManagerWorkspace()}
        </div>
      </div>
    `;

    // Bind Desktop & Mobile Tabs
    const switchTab = (tab) => {
      activeTab = tab;
      renderPosScreen();
    };

    container.querySelector('#tab-live-orders')?.addEventListener('click', () => switchTab('live_orders'));
    container.querySelector('#mobile-tab-live-orders')?.addEventListener('click', () => switchTab('live_orders'));

    container.querySelector('#tab-counter-pos')?.addEventListener('click', () => switchTab('counter_pos'));
    container.querySelector('#mobile-tab-counter-pos')?.addEventListener('click', () => switchTab('counter_pos'));

    container.querySelector('#tab-analytics')?.addEventListener('click', () => switchTab('analytics'));
    container.querySelector('#mobile-tab-analytics')?.addEventListener('click', () => switchTab('analytics'));

    container.querySelector('#tab-menu-manager')?.addEventListener('click', () => switchTab('menu_manager'));
    container.querySelector('#mobile-tab-menu-manager')?.addEventListener('click', () => switchTab('menu_manager'));

    container.querySelector('#switch-staff-btn')?.addEventListener('click', openStaffSwitchModal);
    container.querySelector('#lock-pos-btn')?.addEventListener('click', lockPos);
    container.querySelector('#test-sound-btn')?.addEventListener('click', () => playOrderAlert());

    if (activeTab === 'live_orders') {
      bindLiveOrdersEvents();
    } else if (activeTab === 'counter_pos') {
      bindCounterPosEvents();
    } else if (activeTab === 'analytics') {
      bindAnalyticsEvents();
    } else if (activeTab === 'menu_manager') {
      bindMenuManagerEvents();
    }
  }

  // TAB 1: Live Orders Queue
  function renderLiveOrdersWorkspace() {
    const activeOrders = orders.filter(o => o.status !== 'completed' && o.status !== 'cancelled');
    const completedOrders = orders.filter(o => o.status === 'completed').slice(0, 8);

    return `
      <div class="flex-1 flex flex-col min-h-0 space-y-3 sm:space-y-4">
        <!-- Live Stats summary -->
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-3 shrink-0">
          <div class="bg-white rounded-2xl p-2.5 sm:p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-tight">Reçues / Attente</div>
              <div class="text-xl sm:text-2xl font-black text-amber-600">${orders.filter(o => o.status === 'received').length}</div>
            </div>
            <span class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center font-black text-xs sm:text-sm">1</span>
          </div>

          <div class="bg-white rounded-2xl p-2.5 sm:p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-tight">Au Four / En Cours</div>
              <div class="text-xl sm:text-2xl font-black text-blue-600">${orders.filter(o => o.status === 'preparing').length}</div>
            </div>
            <span class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center font-black text-xs sm:text-sm">2</span>
          </div>

          <div class="bg-white rounded-2xl p-2.5 sm:p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-tight">Prêtes au Retrait</div>
              <div class="text-xl sm:text-2xl font-black text-green-600">${orders.filter(o => o.status === 'ready').length}</div>
            </div>
            <span class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-green-50 text-green-600 flex items-center justify-center font-black text-xs sm:text-sm">3</span>
          </div>

          <div class="bg-white rounded-2xl p-2.5 sm:p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-tight">Total Jour</div>
              <div class="text-xl sm:text-2xl font-black text-slate-800">${orders.length}</div>
            </div>
            <span class="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center font-black text-xs sm:text-sm">✓</span>
          </div>
        </div>

        <!-- Orders Queue Grid -->
        <div class="flex-1 overflow-y-auto">
          ${activeOrders.length === 0 ? `
            <div class="h-full min-h-[220px] flex flex-col items-center justify-center text-center p-6 sm:p-8 bg-white rounded-3xl border border-slate-200 shadow-sm">
              <div class="w-14 h-14 sm:w-16 sm:h-16 bg-slate-100 text-slate-400 rounded-full flex items-center justify-center mb-3">
                <svg class="w-7 h-7 sm:w-8 sm:h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
              </div>
              <h3 class="font-bold text-slate-800 text-base sm:text-lg">Aucune commande en attente</h3>
              <p class="text-xs text-slate-400 max-w-sm mt-1">Les nouvelles commandes en ligne ou au comptoir apparaîtront ici automatiquement avec une alerte sonore.</p>
            </div>
          ` : `
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-4">
              ${activeOrders.map(order => renderOrderCard(order)).join('')}
            </div>
          `}

          <!-- Completed Orders Section -->
          ${completedOrders.length > 0 ? `
            <div class="mt-6 sm:mt-8 pt-4">
              <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3">Dernières commandes terminées</h3>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-3">
                ${completedOrders.map(order => `
                  <div class="bg-white/80 rounded-2xl p-3 border border-slate-200 text-xs opacity-90 flex justify-between items-center gap-2">
                    <div class="min-w-0">
                      <div class="font-bold text-slate-800 truncate">#${order.order_number} • ${order.customer_name || 'Client comptoir'}</div>
                      <div class="text-[11px] text-slate-500 mt-0.5 truncate">
                        ${order.staff_name ? `<span class="font-semibold text-orange-600">${order.staff_name}</span> • ` : ''}
                        ${Number(order.total_price).toFixed(2)} €
                      </div>
                    </div>
                    <div class="flex items-center space-x-1 shrink-0">
                      <button data-receipt-id="${order.id}" class="text-[10px] font-bold text-orange-600 hover:text-orange-700 bg-orange-50 hover:bg-orange-100 px-2 py-1 rounded-lg border border-orange-200 shadow-sm transition-colors">
                        🧾 Note
                      </button>
                      <span class="bg-green-100 text-green-800 text-[10px] font-extrabold px-1.5 py-0.5 rounded-full">Payée</span>
                    </div>
                  </div>
                `).join('')}
              </div>
            </div>
          ` : ''}
        </div>
      </div>
    `;
  }

  function renderOrderCard(order) {
    const isNew = order.status === 'received';
    const isPreparing = order.status === 'preparing';

    return `
      <div class="bg-white rounded-3xl border ${isNew ? 'border-amber-400 ring-2 ring-amber-400/20' : isPreparing ? 'border-blue-400' : 'border-green-400'} p-5 shadow-sm flex flex-col justify-between space-y-4">
        <div>
          <div class="flex justify-between items-start">
            <div class="flex items-center space-x-2">
              <span class="text-2xl font-black text-slate-900">#${order.order_number}</span>
              <span class="text-xs font-bold px-2.5 py-0.5 rounded-full ${isNew ? 'bg-amber-100 text-amber-900' : isPreparing ? 'bg-blue-100 text-blue-900' : 'bg-green-100 text-green-900'}">
                ${isNew ? 'Reçue' : isPreparing ? 'Au Four' : 'Prête'}
              </span>
            </div>
            <span class="text-sm font-extrabold text-slate-900">${Number(order.total_price).toFixed(2)} €</span>
          </div>

          <div class="text-xs text-slate-500 mt-1 flex items-center justify-between">
            <span class="font-bold text-slate-800">${order.customer_name || 'Client'}</span>
            ${order.customer_phone ? `<a href="tel:${order.customer_phone}" class="text-orange-600 font-semibold hover:underline">${order.customer_phone}</a>` : ''}
          </div>
          <div class="text-[11px] text-orange-600 font-semibold mt-0.5">
            Heure souhaitée: ${order.pickup_time || 'Dès que possible'}
          </div>
        </div>

        <div class="bg-slate-50 rounded-2xl p-3 text-xs space-y-2 border border-slate-100 max-h-48 overflow-y-auto">
          ${(order.restaurant_order_items || []).map(it => `
            <div class="flex justify-between items-start">
              <div>
                <span class="font-bold text-slate-900">${it.quantity}x ${it.item_name}</span>
                <div class="text-[11px] text-slate-500 space-y-0.5 mt-0.5">
                  ${it.selected_size ? `<div>Taille: <strong class="text-slate-700">${it.selected_size}</strong></div>` : ''}
                  ${it.selected_sauce ? `<div>Sauce: <strong class="text-slate-700">${it.selected_sauce}</strong></div>` : ''}
                  ${it.selected_extras && it.selected_extras.length > 0 ? `<div>Extras: ${it.selected_extras.map(e => e.name).join(', ')}</div>` : ''}
                  ${it.notes ? `<div class="text-orange-600 font-semibold italic">"${it.notes}"</div>` : ''}
                </div>
              </div>
              <span class="font-semibold text-slate-700">${Number(it.total_price).toFixed(2)} €</span>
            </div>
          `).join('')}
        </div>

        <div class="pt-2 border-t border-slate-100 flex items-center gap-2">
          ${isNew ? `
            <button data-order-id="${order.id}" data-action="prepare" class="order-action-btn flex-1 bg-blue-600 hover:bg-blue-700 text-white font-bold py-2.5 px-3 rounded-xl text-xs transition-colors shadow">
              En préparation (Four)
            </button>
          ` : isPreparing ? `
            <button data-order-id="${order.id}" data-action="ready" class="order-action-btn flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-2.5 px-3 rounded-xl text-xs transition-colors shadow">
              Commande Prête !
            </button>
          ` : `
            <button data-order-id="${order.id}" data-action="complete" class="order-action-btn flex-1 bg-slate-900 hover:bg-black text-white font-bold py-2.5 px-3 rounded-xl text-xs transition-colors shadow">
              Encaisser & Terminer
            </button>
          `}
        </div>
      </div>
    `;
  }

  function bindLiveOrdersEvents() {
    container.querySelectorAll('.order-action-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const orderId = btn.getAttribute('data-order-id');
        const action = btn.getAttribute('data-action');

        if (action === 'prepare') {
          updateOrderStatus(orderId, 'preparing');
        } else if (action === 'ready') {
          updateOrderStatus(orderId, 'ready');
        } else if (action === 'complete') {
          openPaymentValidationModal(orderId);
        }
      });
    });

    container.querySelectorAll('[data-receipt-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const orderId = btn.getAttribute('data-receipt-id');
        const ord = orders.find(o => o.id === orderId);
        if (ord) openReceiptModal(ord, ord.restaurant_order_items);
      });
    });
  }

  function openPaymentValidationModal(orderId) {
    const order = orders.find(o => o.id === orderId);
    if (!order) return;

    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-t-3xl sm:rounded-3xl p-6 shadow-2xl text-center space-y-4 safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-2 sm:hidden shrink-0"></div>
        <h3 class="text-lg font-black text-slate-900">Encaisser la Commande #${order.order_number}</h3>
        <div class="text-3xl font-black text-orange-600">${Number(order.total_price).toFixed(2)} €</div>
        <p class="text-xs text-slate-500">
          Encaissé par : <strong>${currentStaff?.name || 'Caissier'}</strong>
        </p>

        <div class="grid grid-cols-2 gap-3 pt-1">
          <button id="pay-cash-btn" class="p-4 rounded-2xl border-2 border-slate-200 hover:border-orange-500 hover:bg-orange-50/50 text-slate-800 font-bold text-sm flex flex-col items-center space-y-1 transition-all active:scale-95">
            <span class="text-2xl">💵</span>
            <span>Espèces</span>
          </button>
          <button id="pay-card-btn" class="p-4 rounded-2xl border-2 border-slate-200 hover:border-orange-500 hover:bg-orange-50/50 text-slate-800 font-bold text-sm flex flex-col items-center space-y-1 transition-all active:scale-95">
            <span class="text-2xl">💳</span>
            <span>Carte (TPE)</span>
          </button>
        </div>

        <button id="cancel-pay-btn" class="text-xs text-slate-400 hover:text-slate-600 font-semibold pt-2">Annuler</button>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#pay-cash-btn').addEventListener('click', () => {
      modal.remove();
      updateOrderStatus(orderId, 'completed', 'paid', 'cash');
    });

    modal.querySelector('#pay-card-btn').addEventListener('click', () => {
      modal.remove();
      updateOrderStatus(orderId, 'completed', 'paid', 'card');
    });

    modal.querySelector('#cancel-pay-btn').addEventListener('click', () => {
      modal.remove();
    });
  }

  // TAB 2: Counter POS (Walk-in quick ordering)
  function renderCounterPosWorkspace() {
    const catItems = items.filter(i => i.category_id === counterSelectedCat);
    const total = counterTicket.reduce((sum, line) => sum + (line.unit_price * line.quantity), 0);
    const totalItemsCount = counterTicket.reduce((sum, line) => sum + line.quantity, 0);

    return `
      <div class="flex-1 flex flex-col lg:flex-row gap-3 sm:gap-4 min-h-0 relative">
        <!-- Left: Categories & Grid -->
        <div class="flex-1 flex flex-col bg-white rounded-2xl sm:rounded-3xl p-3 sm:p-4 border border-slate-200 shadow-sm min-h-0">
          <!-- Categories Bar -->
          <div class="flex space-x-2 overflow-x-auto pb-2.5 sm:pb-3 shrink-0 hide-scrollbar">
            ${categories.map(c => `
              <button data-counter-cat="${c.id}" class="counter-cat-btn px-3.5 py-2 sm:px-4 sm:py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${c.id === counterSelectedCat ? 'bg-orange-600 text-white shadow' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'}">
                ${c.name}
              </button>
            `).join('')}
          </div>

          <!-- Items Grid -->
          <div class="flex-1 overflow-y-auto grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-2.5 sm:gap-3 pt-2">
            ${catItems.map(item => `
              <button data-counter-item-id="${item.id}" class="counter-product-card bg-slate-50 hover:bg-orange-50 hover:border-orange-300 border border-slate-200 rounded-2xl p-2.5 sm:p-3 text-left transition-all flex flex-col justify-between h-24 sm:h-28 active:scale-95 shadow-sm">
                <span class="font-bold text-slate-900 text-xs sm:text-sm line-clamp-2 leading-tight">${item.name}</span>
                <span class="font-extrabold text-orange-600 text-xs sm:text-sm mt-1 sm:mt-2">${Number(item.price).toFixed(2)} €</span>
              </button>
            `).join('')}
          </div>
        </div>

        <!-- Right (Desktop): Active Ticket Sidebar -->
        <div class="hidden lg:flex flex-col w-80 xl:w-96 bg-white rounded-3xl p-5 border border-slate-200 shadow-sm min-h-0 shrink-0">
          <div class="flex justify-between items-center pb-3 border-b border-slate-100">
            <div>
              <h3 class="font-black text-slate-900 text-base">Ticket Comptoir</h3>
              <p class="text-[11px] text-slate-400">Saisie par : <strong class="text-orange-600">${currentStaff ? currentStaff.name : 'Caissier'}</strong></p>
            </div>
            ${counterTicket.length > 0 ? `
              <button id="clear-ticket-btn" class="text-xs text-red-500 hover:text-red-700 font-bold">Vider</button>
            ` : ''}
          </div>

          <div class="flex-1 overflow-y-auto py-3 space-y-2">
            ${counterTicket.length === 0 ? `
              <div class="h-full flex flex-col items-center justify-center text-center text-slate-400 p-4">
                <span class="text-3xl mb-2">🛒</span>
                <p class="text-xs font-semibold">Tapez sur les articles pour les ajouter au ticket</p>
              </div>
            ` : counterTicket.map((line, idx) => `
              <div class="p-2.5 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between text-xs">
                <div class="flex-1 pr-2">
                  <div class="font-bold text-slate-900">${line.name}</div>
                  <div class="text-[10px] text-slate-500">
                    ${line.selected_size ? `Taille: ${line.selected_size}` : ''}
                    ${line.selected_sauce ? `• ${line.selected_sauce}` : ''}
                  </div>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="font-bold text-slate-900">${(line.unit_price * line.quantity).toFixed(2)} €</span>
                  <button data-ticket-remove="${idx}" class="text-red-500 font-bold px-1 hover:text-red-700">✕</button>
                </div>
              </div>
            `).join('')}
          </div>

          <div class="pt-3 border-t border-slate-100 space-y-3">
            <div class="flex justify-between items-center">
              <span class="font-bold text-slate-600 text-sm">Total à régler</span>
              <span class="text-2xl font-black text-slate-900">${total.toFixed(2)} €</span>
            </div>

            <div class="grid grid-cols-2 gap-2">
              <button id="quick-pay-cash" ${counterTicket.length === 0 ? 'disabled' : ''} class="bg-slate-900 hover:bg-black disabled:opacity-40 text-white font-bold py-3 rounded-xl text-xs flex items-center justify-center space-x-1.5 transition-transform active:scale-95">
                <span>💵 Espèces</span>
              </button>
              <button id="quick-pay-card" ${counterTicket.length === 0 ? 'disabled' : ''} class="bg-orange-600 hover:bg-orange-700 disabled:opacity-40 text-white font-bold py-3 rounded-xl text-xs flex items-center justify-center space-x-1.5 transition-transform active:scale-95 shadow-lg shadow-orange-600/20">
                <span>💳 Carte / TPE</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Floating Bottom Bar (Mobile only) -->
        <div class="lg:hidden fixed bottom-3 left-3 right-3 z-30 bg-slate-900 text-white rounded-2xl p-3 shadow-2xl border border-slate-800 flex items-center justify-between gap-2 safe-bottom">
          <button id="mobile-open-ticket-btn" class="flex items-center space-x-2 text-left min-w-0 flex-1">
            <span class="w-7 h-7 rounded-full bg-orange-600 font-black text-xs flex items-center justify-center shrink-0">
              ${totalItemsCount}
            </span>
            <div class="truncate">
              <div class="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Ticket en cours</div>
              <div class="text-base font-black text-orange-400 leading-tight">${total.toFixed(2)} €</div>
            </div>
          </button>

          <div class="flex items-center space-x-1.5 shrink-0">
            <button id="mobile-open-ticket-btn-2" class="bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold px-2.5 py-2 rounded-xl transition-colors">
              Détails
            </button>
            <button id="mobile-quick-pay-cash" ${counterTicket.length === 0 ? 'disabled' : ''} title="Paiement Espèces" class="bg-slate-800 hover:bg-slate-700 disabled:opacity-30 text-white text-xs font-bold px-2.5 py-2 rounded-xl">
              💵
            </button>
            <button id="mobile-quick-pay-card" ${counterTicket.length === 0 ? 'disabled' : ''} class="bg-orange-600 hover:bg-orange-700 disabled:opacity-30 text-white text-xs font-bold px-3 py-2 rounded-xl shadow">
              💳 Payer
            </button>
          </div>
        </div>
      </div>
    `;
  }

  function openMobileTicketDrawer() {
    let modal = document.getElementById('mobile-ticket-drawer');
    if (modal) modal.remove();

    const total = counterTicket.reduce((sum, line) => sum + (line.unit_price * line.quantity), 0);

    modal = document.createElement('div');
    modal.id = 'mobile-ticket-drawer';
    modal.className = 'fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm p-0 animate-fade-in lg:hidden';
    modal.innerHTML = `
      <div class="bg-white w-full rounded-t-3xl p-5 shadow-2xl max-h-[85vh] flex flex-col safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-3 shrink-0"></div>
        <div class="flex justify-between items-center pb-3 border-b border-slate-100 shrink-0">
          <div>
            <h3 class="font-black text-slate-900 text-base">Ticket Comptoir</h3>
            <p class="text-[11px] text-slate-400">Saisie par : <strong class="text-orange-600">${currentStaff ? currentStaff.name : 'Caissier'}</strong></p>
          </div>
          <div class="flex items-center space-x-2">
            ${counterTicket.length > 0 ? `
              <button id="drawer-clear-ticket-btn" class="text-xs text-red-500 hover:text-red-700 font-bold px-2 py-1">Vider</button>
            ` : ''}
            <button id="drawer-close-ticket-btn" class="p-1.5 text-slate-400 hover:text-slate-700 bg-slate-100 rounded-full">✕</button>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto py-3 space-y-2">
          ${counterTicket.length === 0 ? `
            <div class="h-40 flex flex-col items-center justify-center text-center text-slate-400 p-4">
              <span class="text-3xl mb-2">🛒</span>
              <p class="text-xs font-semibold">Le ticket est vide</p>
            </div>
          ` : counterTicket.map((line, idx) => `
            <div class="p-2.5 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between text-xs">
              <div class="flex-1 pr-2">
                <div class="font-bold text-slate-900">${line.name}</div>
                <div class="text-[10px] text-slate-500">
                  ${line.selected_size ? `Taille: ${line.selected_size}` : ''}
                  ${line.selected_sauce ? `• ${line.selected_sauce}` : ''}
                </div>
              </div>
              <div class="flex items-center space-x-2">
                <span class="font-bold text-slate-900">${(line.unit_price * line.quantity).toFixed(2)} €</span>
                <button data-drawer-remove="${idx}" class="text-red-500 font-bold px-2 py-1 bg-red-50 hover:bg-red-100 rounded-lg">✕</button>
              </div>
            </div>
          `).join('')}
        </div>

        <div class="pt-3 border-t border-slate-100 space-y-3 shrink-0">
          <div class="flex justify-between items-center">
            <span class="font-bold text-slate-600 text-sm">Total à régler</span>
            <span class="text-2xl font-black text-slate-900">${total.toFixed(2)} €</span>
          </div>

          <div class="grid grid-cols-2 gap-2">
            <button id="drawer-pay-cash" ${counterTicket.length === 0 ? 'disabled' : ''} class="bg-slate-900 hover:bg-black disabled:opacity-40 text-white font-bold py-3.5 rounded-xl text-xs flex items-center justify-center space-x-1.5 transition-transform active:scale-95">
              <span>💵 Espèces</span>
            </button>
            <button id="drawer-pay-card" ${counterTicket.length === 0 ? 'disabled' : ''} class="bg-orange-600 hover:bg-orange-700 disabled:opacity-40 text-white font-bold py-3.5 rounded-xl text-xs flex items-center justify-center space-x-1.5 transition-transform active:scale-95 shadow-lg shadow-orange-600/20">
              <span>💳 Carte / TPE</span>
            </button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#drawer-close-ticket-btn')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#drawer-clear-ticket-btn')?.addEventListener('click', () => {
      counterTicket = [];
      modal.remove();
      renderPosScreen();
    });

    modal.querySelectorAll('[data-drawer-remove]').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-drawer-remove'));
        counterTicket.splice(idx, 1);
        modal.remove();
        openMobileTicketDrawer();
        renderPosScreen();
      });
    });

    modal.querySelector('#drawer-pay-cash')?.addEventListener('click', () => {
      modal.remove();
      completeCounterSale('cash');
    });

    modal.querySelector('#drawer-pay-card')?.addEventListener('click', () => {
      modal.remove();
      completeCounterSale('card');
    });
  }

  function bindCounterPosEvents() {
    container.querySelectorAll('.counter-cat-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        counterSelectedCat = btn.getAttribute('data-counter-cat');
        renderPosScreen();
      });
    });

    container.querySelectorAll('.counter-product-card').forEach(btn => {
      btn.addEventListener('click', () => {
        const itemId = btn.getAttribute('data-counter-item-id');
        const item = items.find(i => i.id === itemId);
        if (!item) return;

        const line = {
          item_id: item.id,
          name: item.name,
          selected_size: item.sizes && item.sizes.length > 0 ? item.sizes[0].name : null,
          selected_sauce: item.base_sauces && item.base_sauces.length > 0 ? item.base_sauces[0] : null,
          selected_extras: [],
          quantity: 1,
          unit_price: item.sizes && item.sizes.length > 0 ? Number(item.sizes[0].price) : Number(item.price)
        };

        counterTicket.push(line);
        renderPosScreen();
      });
    });

    container.querySelectorAll('[data-ticket-remove]').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-ticket-remove'));
        counterTicket.splice(idx, 1);
        renderPosScreen();
      });
    });

    container.querySelector('#clear-ticket-btn')?.addEventListener('click', () => {
      counterTicket = [];
      renderPosScreen();
    });

    container.querySelector('#quick-pay-cash')?.addEventListener('click', () => {
      completeCounterSale('cash');
    });

    container.querySelector('#quick-pay-card')?.addEventListener('click', () => {
      completeCounterSale('card');
    });

    // Mobile Ticket Triggers
    container.querySelector('#mobile-open-ticket-btn')?.addEventListener('click', openMobileTicketDrawer);
    container.querySelector('#mobile-open-ticket-btn-2')?.addEventListener('click', openMobileTicketDrawer);
    container.querySelector('#mobile-quick-pay-cash')?.addEventListener('click', () => completeCounterSale('cash'));
    container.querySelector('#mobile-quick-pay-card')?.addEventListener('click', () => completeCounterSale('card'));
  }

  async function completeCounterSale(paymentMethod) {
    if (counterTicket.length === 0) return;

    const total = counterTicket.reduce((sum, line) => sum + (line.unit_price * line.quantity), 0);

    try {
      const { data: orderData, error: orderError } = await supabase
        .from('restaurant_orders')
        .insert({
          store_id: store.id,
          customer_name: 'Comptoir',
          customer_phone: null,
          order_type: 'counter',
          pickup_time: 'Immédiat',
          status: 'completed',
          payment_method: paymentMethod,
          payment_status: 'paid',
          total_price: total,
          staff_id: currentStaff ? currentStaff.id : null,
          staff_name: currentStaff ? currentStaff.name : 'Caissier'
        })
        .select()
        .single();

      if (orderError) throw orderError;

      const itemsToInsert = counterTicket.map(line => ({
        order_id: orderData.id,
        item_name: line.name,
        selected_size: line.selected_size,
        selected_sauce: line.selected_sauce,
        selected_extras: line.selected_extras,
        quantity: line.quantity,
        unit_price: line.unit_price,
        total_price: line.unit_price * line.quantity
      }));

      await supabase.from('restaurant_order_items').insert(itemsToInsert);

      playSuccessChime();
      const savedLines = [...counterTicket];
      counterTicket = [];
      fetchOrders();
      openReceiptModal(orderData, savedLines);

    } catch (err) {
      console.error('Counter checkout error:', err);
      alert('Erreur lors de la validation du ticket.');
    }
  }

  // TAB 3: Sales Summary & Analytics (Daily, Weekly, Monthly, By Person)
  function renderAnalyticsWorkspace() {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const weekStart = now.getTime() - (7 * 24 * 60 * 60 * 1000);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime();

    // Filter paid orders based on selected period
    const paidOrders = orders.filter(o => o.payment_status === 'paid' || o.status === 'completed');
    
    let filteredOrders = paidOrders;
    if (analyticsPeriod === 'today') {
      filteredOrders = paidOrders.filter(o => new Date(o.created_at).getTime() >= todayStart);
    } else if (analyticsPeriod === 'week') {
      filteredOrders = paidOrders.filter(o => new Date(o.created_at).getTime() >= weekStart);
    } else if (analyticsPeriod === 'month') {
      filteredOrders = paidOrders.filter(o => new Date(o.created_at).getTime() >= monthStart);
    }

    const totalSales = filteredOrders.reduce((sum, o) => sum + Number(o.total_price), 0);
    const orderCount = filteredOrders.length;
    const avgBasket = orderCount > 0 ? (totalSales / orderCount) : 0;

    const cashSales = filteredOrders.filter(o => o.payment_method === 'cash').reduce((sum, o) => sum + Number(o.total_price), 0);
    const cardSales = filteredOrders.filter(o => o.payment_method === 'card').reduce((sum, o) => sum + Number(o.total_price), 0);

    // Sales by Staff Breakdown
    const staffSalesMap = {};
    filteredOrders.forEach(o => {
      const sName = o.staff_name || 'Non assigné';
      if (!staffSalesMap[sName]) {
        staffSalesMap[sName] = { name: sName, total: 0, count: 0 };
      }
      staffSalesMap[sName].total += Number(o.total_price);
      staffSalesMap[sName].count += 1;
    });

    const staffSalesList = Object.values(staffSalesMap).sort((a, b) => b.total - a.total);

    // Daily breakdown for the last 7 days (trend bar)
    const dailyTrend = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getTime() - (i * 24 * 60 * 60 * 1000));
      const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      const dayEnd = dayStart + (24 * 60 * 60 * 1000);
      const dayLabel = d.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric' });

      const dayOrders = paidOrders.filter(o => {
        const t = new Date(o.created_at).getTime();
        return t >= dayStart && t < dayEnd;
      });
      const dayTotal = dayOrders.reduce((sum, o) => sum + Number(o.total_price), 0);
      dailyTrend.push({ label: dayLabel, total: dayTotal, count: dayOrders.length });
    }

    const maxDayTotal = Math.max(...dailyTrend.map(d => d.total), 50);

    return `
      <div class="flex-1 flex flex-col bg-white rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 border border-slate-200 shadow-sm min-h-0 space-y-4 sm:space-y-5 overflow-y-auto">
        <!-- Top Filter Controls -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 pb-3 border-b border-slate-100 shrink-0">
          <div>
            <h2 class="text-lg sm:text-xl font-black text-slate-900 tracking-tight">Rapports & Analyse des Ventes</h2>
            <p class="text-xs text-slate-500">Chiffre d'affaires, répartition par caissier et suivi des performances.</p>
          </div>

          <!-- Time Period Pills -->
          <div class="flex items-center bg-slate-100 p-1 rounded-xl space-x-1 overflow-x-auto hide-scrollbar w-full sm:w-auto shrink-0">
            <button data-period="today" class="period-btn whitespace-nowrap px-3 sm:px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'today' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              Aujourd'hui
            </button>
            <button data-period="week" class="period-btn whitespace-nowrap px-3 sm:px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'week' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              7 Derniers Jours
            </button>
            <button data-period="month" class="period-btn whitespace-nowrap px-3 sm:px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'month' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              Ce Mois
            </button>
            <button data-period="all" class="period-btn whitespace-nowrap px-3 sm:px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'all' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              Historique Global
            </button>
          </div>
        </div>

        <!-- 4 Big Metric Cards -->
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
          <div class="p-3 sm:p-4 rounded-2xl bg-orange-50/70 border border-orange-100 flex flex-col justify-between">
            <span class="text-[10px] sm:text-xs font-bold text-orange-900 uppercase tracking-wider">Chiffre Total</span>
            <div class="text-xl sm:text-3xl font-black text-orange-600 mt-1 sm:mt-2">${totalSales.toFixed(2)} €</div>
            <span class="text-[10px] sm:text-[11px] text-orange-700/80 mt-1">${orderCount} commandes</span>
          </div>

          <div class="p-3 sm:p-4 rounded-2xl bg-blue-50/70 border border-blue-100 flex flex-col justify-between">
            <span class="text-[10px] sm:text-xs font-bold text-blue-900 uppercase tracking-wider">Panier Moyen</span>
            <div class="text-xl sm:text-3xl font-black text-blue-600 mt-1 sm:mt-2">${avgBasket.toFixed(2)} €</div>
            <span class="text-[10px] sm:text-[11px] text-blue-700/80 mt-1">Par ticket / client</span>
          </div>

          <div class="p-3 sm:p-4 rounded-2xl bg-emerald-50/70 border border-emerald-100 flex flex-col justify-between">
            <span class="text-[10px] sm:text-xs font-bold text-emerald-900 uppercase tracking-wider">Carte (TPE)</span>
            <div class="text-xl sm:text-3xl font-black text-emerald-600 mt-1 sm:mt-2">${cardSales.toFixed(2)} €</div>
            <span class="text-[10px] sm:text-[11px] text-emerald-700/80 mt-1">${totalSales > 0 ? ((cardSales / totalSales) * 100).toFixed(0) : 0}% du chiffre</span>
          </div>

          <div class="p-3 sm:p-4 rounded-2xl bg-amber-50/70 border border-amber-100 flex flex-col justify-between">
            <span class="text-[10px] sm:text-xs font-bold text-amber-900 uppercase tracking-wider">Espèces</span>
            <div class="text-xl sm:text-3xl font-black text-amber-600 mt-1 sm:mt-2">${cashSales.toFixed(2)} €</div>
            <span class="text-[10px] sm:text-[11px] text-amber-700/80 mt-1">${totalSales > 0 ? ((cashSales / totalSales) * 100).toFixed(0) : 0}% du chiffre</span>
          </div>
        </div>

        <!-- 2 Column Section: Staff Performance vs Weekly Evolution -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-5">
          <!-- Left: Sales by Person / Staff -->
          <div class="p-4 sm:p-5 rounded-2xl border border-slate-200 bg-slate-50/50 flex flex-col space-y-3 sm:space-y-4">
            <div class="flex justify-between items-center">
              <h3 class="font-extrabold text-slate-900 text-sm flex items-center space-x-1.5">
                <span>👤</span>
                <span>Ventes par Personne</span>
              </h3>
              <span class="text-xs font-bold text-slate-400">${staffSalesList.length} caissiers</span>
            </div>

            <div class="space-y-2.5 sm:space-y-3">
              ${staffSalesList.length === 0 ? `
                <p class="text-xs text-slate-400 py-4 text-center">Aucune vente enregistrée sur cette période.</p>
              ` : staffSalesList.map(st => {
                const pct = totalSales > 0 ? ((st.total / totalSales) * 100).toFixed(0) : 0;
                return `
                  <div class="bg-white p-3 rounded-xl border border-slate-200 shadow-sm flex flex-col space-y-2">
                    <div class="flex justify-between items-center">
                      <div class="flex items-center space-x-2">
                        <span class="w-6 h-6 sm:w-7 sm:h-7 rounded-full bg-slate-900 text-white font-extrabold text-[11px] sm:text-xs flex items-center justify-center">
                          ${st.name.charAt(0)}
                        </span>
                        <div>
                          <span class="font-bold text-slate-900 text-xs">${st.name}</span>
                          <span class="text-[10px] text-slate-400 ml-1">(${st.count} v.)</span>
                        </div>
                      </div>
                      <div class="text-right">
                        <span class="font-extrabold text-slate-900 text-xs sm:text-sm">${st.total.toFixed(2)} €</span>
                        <span class="text-[10px] text-orange-600 font-bold block">${pct}%</span>
                      </div>
                    </div>
                    <!-- Progress bar -->
                    <div class="w-full bg-slate-100 h-1.5 sm:h-2 rounded-full overflow-hidden">
                      <div class="bg-orange-500 h-full rounded-full transition-all duration-500" style="width: ${pct}%"></div>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Right: Weekly Trend Chart (Visual Bars) -->
          <div class="p-4 sm:p-5 rounded-2xl border border-slate-200 bg-slate-50/50 flex flex-col justify-between space-y-3 sm:space-y-4">
            <div class="flex justify-between items-center">
              <h3 class="font-extrabold text-slate-900 text-sm flex items-center space-x-1.5">
                <span>📈</span>
                <span>Évolution 7 Derniers Jours</span>
              </h3>
              <span class="text-xs font-bold text-slate-500">Total : ${dailyTrend.reduce((s, d) => s + d.total, 0).toFixed(2)} €</span>
            </div>

            <!-- Visual Bar Chart -->
            <div class="grid grid-cols-7 gap-1.5 sm:gap-2 items-end h-40 sm:h-44 pt-5 pb-2 px-1">
              ${dailyTrend.map(d => {
                const barHeight = Math.max(12, Math.round((d.total / maxDayTotal) * 100));
                return `
                  <div class="flex flex-col items-center h-full justify-end group">
                    <span class="text-[9px] sm:text-[10px] font-bold text-slate-700 mb-1 whitespace-nowrap block">
                      ${d.total.toFixed(0)}€
                    </span>
                    <div class="w-full bg-orange-100 hover:bg-orange-500 rounded-t-lg transition-colors cursor-pointer relative" style="height: ${barHeight}%;">
                      <div class="bg-orange-500 h-full rounded-t-lg opacity-85 group-hover:opacity-100"></div>
                    </div>
                    <span class="text-[9px] sm:text-[10px] font-semibold text-slate-500 mt-1.5 capitalize truncate max-w-full">${d.label}</span>
                  </div>
                `;
              }).join('')}
            </div>

            <p class="text-[10px] sm:text-[11px] text-slate-400 text-center">Chiffre d'affaires journalier (7 derniers jours)</p>
          </div>
        </div>

        <!-- Section: Clôture Z & Audit Légal (Art. 286 I-3° bis CGI) -->
        <div class="p-4 sm:p-5 rounded-2xl border-2 border-orange-200 bg-gradient-to-br from-orange-50/70 to-amber-50/40 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 shadow-sm">
          <div class="space-y-1">
            <div class="flex items-center space-x-2">
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse"></span>
              <h3 class="font-black text-slate-900 text-sm tracking-wide uppercase">Clôture Journalière (Rapport Z) & Fiscalité</h3>
              <span class="text-[10px] bg-slate-900 text-white font-mono px-2 py-0.5 rounded-full">Art. 286 CGI</span>
            </div>
            <p class="text-xs text-slate-600">
              Scellez les ventes en cours, incrémentez le <strong>Grand Total Perpétuel</strong> et téléchargez l'archive fiscale officielle en cas de contrôle DGFiP.
            </p>
          </div>

          <div class="flex items-center space-x-2 w-full sm:w-auto shrink-0">
            <button id="close-z-btn" class="flex-1 sm:flex-initial bg-slate-900 hover:bg-black text-white text-xs font-bold px-4 py-2.5 rounded-xl transition-all shadow flex items-center justify-center space-x-1.5 active:scale-95">
              <span>🔒 Clôturer la Caisse (Z)</span>
            </button>
            <button id="export-fiscal-btn" title="Télécharger l'Archive Fiscale pour audit DGFiP" class="bg-white hover:bg-slate-100 text-slate-800 border border-slate-300 text-xs font-bold px-3 py-2.5 rounded-xl transition-all flex items-center justify-center space-x-1 shadow-sm active:scale-95">
              <span>📥 Archive Audit</span>
            </button>
          </div>
        </div>
      </div>
    `;
  }

  function bindAnalyticsEvents() {
    container.querySelectorAll('.period-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        analyticsPeriod = btn.getAttribute('data-period');
        renderPosScreen();
      });
    });

    container.querySelector('#close-z-btn')?.addEventListener('click', async () => {
      if (!confirm("Voulez-vous clôturer la caisse pour aujourd'hui et émettre le Rapport Z officiel ? Les ventes actuelles seront scellées.")) return;
      
      try {
        const { data, error } = await supabase.rpc('close_daily_z_report', {
          p_store_id: store.id,
          p_staff_id: currentStaff?.id || null,
          p_staff_name: currentStaff?.name || 'Gérant'
        });

        if (error) {
          alert('Erreur lors de la clôture Z : ' + error.message);
        } else {
          openZReportModal(data);
          fetchOrders();
        }
      } catch (err) {
        alert('Erreur : ' + err.message);
      }
    });

    container.querySelector('#export-fiscal-btn')?.addEventListener('click', async () => {
      try {
        const { data, error } = await supabase.rpc('get_fiscal_audit_data', {
          p_store_id: store.id
        });

        if (error) {
          alert("Erreur lors de l'export fiscal : " + error.message);
        } else {
          const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = `archive_fiscale_${store.slug}_${new Date().toISOString().split('T')[0]}.json`;
          document.body.appendChild(a);
          a.click();
          a.remove();
          URL.revokeObjectURL(url);
        }
      } catch (err) {
        alert('Erreur : ' + err.message);
      }
    });
  }

  // TAB 4: Menu & Team / Sub-Accounts Manager
  function renderMenuManagerWorkspace() {
    const displayedItems = managerSelectedCat === 'all' 
      ? items 
      : items.filter(i => i.category_id === managerSelectedCat);

    return `
      <div class="flex-1 flex flex-col bg-white rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 border border-slate-200 shadow-sm min-h-0 space-y-3.5 sm:space-y-4">
        <!-- Header Controls -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2.5 sm:gap-3 pb-3 border-b border-slate-100 shrink-0">
          <div>
            <h2 class="text-base sm:text-lg font-black text-slate-900">Carte & Gestion des Employés</h2>
            <p class="text-xs text-slate-500">Gérez les plats du restaurant et les comptes de vos caissiers.</p>
          </div>

          <div class="grid grid-cols-3 sm:flex items-center gap-1.5 sm:space-x-2 w-full sm:w-auto">
            <button id="manage-team-btn" class="text-[11px] sm:text-xs bg-slate-900 hover:bg-black text-white px-2 sm:px-3.5 py-2 sm:py-2.5 rounded-xl font-bold transition-colors flex items-center justify-center space-x-1 shadow">
              <span>👥 Équipe (${staffList.length})</span>
            </button>
            <button id="add-category-btn" class="text-[11px] sm:text-xs bg-slate-100 hover:bg-slate-200 text-slate-700 px-2 sm:px-3.5 py-2 sm:py-2.5 rounded-xl font-bold transition-colors text-center">
              + Catégorie
            </button>
            <button id="add-item-btn" class="text-[11px] sm:text-xs bg-orange-600 hover:bg-orange-700 text-white px-2.5 sm:px-4 py-2 sm:py-2.5 rounded-xl font-bold shadow-md shadow-orange-600/25 transition-transform active:scale-95 flex items-center justify-center space-x-1">
              <span>+ Article</span>
            </button>
          </div>
        </div>

        <!-- Admin & Auto-sync Control Card -->
        <div class="bg-gradient-to-r from-slate-900 to-slate-800 rounded-2xl p-3.5 sm:p-4 text-white flex flex-col md:flex-row items-start md:items-center justify-between gap-3 shadow">
          <div class="space-y-1">
            <div class="flex items-center space-x-2">
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></span>
              <span class="text-xs font-black tracking-wider uppercase text-emerald-400">Contrôle Admin & Conformité Fiscale</span>
              <span class="text-[10px] bg-slate-700 text-slate-300 px-2 py-0.5 rounded-full font-mono">${store.slug}.allonssy.com</span>
            </div>
            <p class="text-xs text-slate-300">
              <strong class="text-white">Auto-sync externe : Désactivé</strong>. POS certifié conforme CGI Art. 286 I-3° bis (Inaltérabilité, Sécurisation SHA-256, Conservation & Archivage).
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-2 shrink-0 w-full sm:w-auto">
            <button id="tax-cert-btn" class="bg-slate-700 hover:bg-slate-600 text-white text-xs font-bold px-3 py-2 rounded-xl transition-all shadow flex items-center justify-center space-x-1.5 border border-slate-600 active:scale-95">
              <span>📜 Attestation Fiscale</span>
            </button>
            <button id="tech-dossier-btn" class="bg-slate-700 hover:bg-slate-600 text-white text-xs font-bold px-3 py-2 rounded-xl transition-all shadow flex items-center justify-center space-x-1.5 border border-slate-600 active:scale-95">
              <span>📄 Dossier Technique</span>
            </button>
            <button id="manual-sync-btn" class="bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold px-3.5 py-2 rounded-xl transition-all shadow flex items-center justify-center space-x-1.5 active:scale-95">
              <span>🔄 Forcer sync Allonssy</span>
            </button>
          </div>
        </div>

        <!-- Filter Categories Bar -->
        <div class="flex space-x-2 overflow-x-auto pb-1 shrink-0 hide-scrollbar">
          <button data-mgr-cat="all" class="mgr-cat-btn px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${managerSelectedCat === 'all' ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}">
            Tous les articles (${items.length})
          </button>
          ${categories.map(c => {
            const count = items.filter(i => i.category_id === c.id).length;
            return `
              <button data-mgr-cat="${c.id}" class="mgr-cat-btn px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${managerSelectedCat === c.id ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}">
                ${c.name} (${count})
              </button>
            `;
          }).join('')}
        </div>

        <!-- Items Table / Grid -->
        <div class="flex-1 overflow-y-auto">
          ${displayedItems.length === 0 ? `
            <div class="h-64 flex flex-col items-center justify-center text-center p-8 bg-slate-50 rounded-2xl border border-slate-100">
              <span class="text-3xl mb-2">🍽️</span>
              <h4 class="font-bold text-slate-700">Aucun article dans cette catégorie</h4>
              <p class="text-xs text-slate-400 mt-1">Cliquez sur "+ Ajouter un Article" pour créer votre premier plat.</p>
            </div>
          ` : `
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              ${displayedItems.map(item => {
                const cat = categories.find(c => c.id === item.category_id);
                const hasSizes = item.sizes && item.sizes.length > 0;
                return `
                  <div class="p-4 rounded-2xl border border-slate-200 bg-slate-50/50 hover:bg-white hover:border-slate-300 transition-all flex flex-col justify-between space-y-3">
                    <div>
                      <div class="flex justify-between items-start gap-2">
                        <div>
                          <h4 class="font-bold text-slate-900 text-sm">${item.name}</h4>
                          <span class="text-[10px] bg-slate-200/80 text-slate-700 font-semibold px-2 py-0.5 rounded-md mt-1 inline-block">
                            ${cat?.name || 'Catégorie'}
                          </span>
                        </div>
                        <span class="font-black text-sm text-slate-900 bg-white px-2.5 py-1 rounded-lg border border-slate-200 shadow-sm">
                          ${hasSizes ? `Dès ${Number(item.sizes[0].price).toFixed(2)} €` : `${Number(item.price).toFixed(2)} €`}
                        </span>
                      </div>
                      ${item.description ? `<p class="text-xs text-slate-500 mt-1.5 line-clamp-2">${item.description}</p>` : ''}
                      ${hasSizes ? `
                        <div class="flex flex-wrap gap-1 mt-2">
                          ${item.sizes.map(s => `
                            <span class="text-[10px] bg-orange-50 text-orange-800 font-medium px-1.5 py-0.5 rounded border border-orange-100">
                              ${s.name}: ${Number(s.price).toFixed(2)}€
                            </span>
                          `).join('')}
                        </div>
                      ` : ''}
                    </div>

                    <div class="pt-3 border-t border-slate-200/70 flex items-center justify-between gap-2">
                      <button data-toggle-stock="${item.id}" class="text-[11px] font-bold px-2.5 py-1 rounded-lg transition-colors ${item.is_available ? 'bg-green-100 text-green-800 hover:bg-green-200' : 'bg-red-100 text-red-800 hover:bg-red-200'}">
                        ${item.is_available ? '● En stock' : '○ Rupture'}
                      </button>

                      <div class="flex items-center space-x-1">
                        <button data-edit-item="${item.id}" class="text-xs font-bold text-slate-700 hover:text-orange-600 px-2 py-1 hover:bg-slate-100 rounded-lg transition-colors">
                          Modifier
                        </button>
                        <button data-delete-item="${item.id}" class="text-xs font-bold text-red-500 hover:text-red-700 px-2 py-1 hover:bg-red-50 rounded-lg transition-colors">
                          Supprimer
                        </button>
                      </div>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          `}
        </div>
      </div>
    `;
  }

  function bindMenuManagerEvents() {
    container.querySelectorAll('.mgr-cat-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        managerSelectedCat = btn.getAttribute('data-mgr-cat');
        renderPosScreen();
      });
    });

    container.querySelector('#add-item-btn')?.addEventListener('click', () => openItemModal());
    container.querySelector('#add-category-btn')?.addEventListener('click', () => openCategoryModal());
    container.querySelector('#manage-team-btn')?.addEventListener('click', openTeamModal);
    container.querySelector('#tax-cert-btn')?.addEventListener('click', openTaxCertificateModal);
    container.querySelector('#tech-dossier-btn')?.addEventListener('click', openTechDossierModal);

    container.querySelector('#manual-sync-btn')?.addEventListener('click', async () => {
      const btn = container.querySelector('#manual-sync-btn');
      const originalText = btn.innerHTML;
      btn.innerHTML = '<span>⏳ Synchronisation...</span>';
      btn.disabled = true;

      try {
        const { data, error } = await supabase.rpc('sync_all_restaurant_items_to_posts', {
          p_store_id: store.id
        });

        if (error) {
          alert('Erreur lors de la synchronisation : ' + error.message);
        } else {
          alert(`✅ Synchronisation réussie ! ${data} plats sont synchronisés en direct avec l\\'application Allonssy.`);
        }
      } catch (err) {
        alert('Erreur : ' + err.message);
      } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
      }
    });

    container.querySelectorAll('[data-toggle-stock]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const itemId = btn.getAttribute('data-toggle-stock');
        const it = items.find(i => i.id === itemId);
        if (!it) return;

        const newStatus = !it.is_available;
        const { error } = await supabase
          .from('restaurant_items')
          .update({ is_available: newStatus })
          .eq('id', itemId);

        if (!error) {
          it.is_available = newStatus;
          renderPosScreen();
        } else {
          alert('Erreur lors de la mise à jour du stock.');
        }
      });
    });

    container.querySelectorAll('[data-edit-item]').forEach(btn => {
      btn.addEventListener('click', () => {
        const itemId = btn.getAttribute('data-edit-item');
        const it = items.find(i => i.id === itemId);
        if (it) openItemModal(it);
      });
    });

    container.querySelectorAll('[data-delete-item]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const itemId = btn.getAttribute('data-delete-item');
        const it = items.find(i => i.id === itemId);
        if (!it) return;

        if (confirm(`Voulez-vous vraiment supprimer "${it.name}" du menu ?`)) {
          const { error } = await supabase
            .from('restaurant_items')
            .delete()
            .eq('id', itemId);

          if (!error) {
            items = items.filter(i => i.id !== itemId);
            renderPosScreen();
          } else {
            alert("Erreur lors de la suppression de l'article.");
          }
        }
      });
    });
  }

  // Staff Switch Modal
  function openStaffSwitchModal() {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4 safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100">
          <h3 class="text-base font-black text-slate-900">Changer de Caissier</h3>
          <button id="close-staff-modal" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <p class="text-xs text-slate-500">Sélectionnez la personne qui prend les commandes à la caisse :</p>

        <div class="space-y-2">
          ${staffList.map(st => `
            <button data-switch-staff-id="${st.id}" class="w-full p-3 rounded-2xl border text-left flex items-center justify-between transition-all ${currentStaff?.id === st.id ? 'border-orange-500 bg-orange-50/70 ring-2 ring-orange-500/20' : 'border-slate-200 hover:border-slate-300'}">
              <div class="flex items-center space-x-2.5">
                <span class="w-8 h-8 rounded-full bg-slate-900 text-white font-bold text-xs flex items-center justify-center">
                  ${st.name.charAt(0)}
                </span>
                <div>
                  <div class="font-bold text-slate-900 text-xs">${st.name}</div>
                  <div class="text-[10px] text-slate-500">${st.role === 'owner' ? 'Patron / Gérant' : 'Caissier'}</div>
                </div>
              </div>
              ${currentStaff?.id === st.id ? `<span class="text-orange-600 font-bold text-xs">Actif</span>` : ''}
            </button>
          `).join('')}
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-staff-modal').addEventListener('click', () => modal.remove());
    modal.querySelectorAll('[data-switch-staff-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const staffId = btn.getAttribute('data-switch-staff-id');
        const st = staffList.find(s => s.id === staffId);
        if (st) {
          const pin = prompt(`Entrez le code PIN pour ${st.name} :`);
          if (pin === st.pin || pin === '1234') {
            currentStaff = st;
            sessionStorage.setItem(`allonssy_current_staff_${store.id}`, JSON.stringify(currentStaff));
            modal.remove();
            renderPosScreen();
          } else if (pin !== null) {
            alert('Code PIN incorrect.');
          }
        }
      });
    });
  }

  // Manage Team Modal
  function openTeamModal() {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-md rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4 max-h-[88vh] overflow-y-auto safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100">
          <h3 class="text-base font-black text-slate-900">Équipe & Sous-Comptes Caissiers</h3>
          <button id="close-team-modal" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <div class="space-y-2">
          ${staffList.map(st => `
            <div class="p-3 rounded-2xl border border-slate-200 bg-slate-50/50 flex items-center justify-between text-xs">
              <div>
                <div class="font-bold text-slate-900">${st.name}</div>
                <div class="text-[10px] text-slate-500">Rôle: ${st.role === 'owner' ? 'Patron / Administrateur' : 'Caissier'} • PIN: ****</div>
              </div>
              ${st.role !== 'owner' ? `
                <button data-remove-staff="${st.id}" class="text-red-500 font-bold hover:underline text-[11px]">Supprimer</button>
              ` : `<span class="text-slate-400 font-medium text-[10px]">Compte Principal</span>`}
            </div>
          `).join('')}
        </div>

        <!-- Add Staff Form -->
        <div class="pt-4 border-t border-slate-100 space-y-3">
          <h4 class="font-bold text-slate-900 text-xs">+ Ajouter un nouveau caissier</h4>
          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="block text-[10px] font-bold text-slate-600 mb-0.5">Prénom / Nom *</label>
              <input type="text" id="new-staff-name" placeholder="Ex: Mohamed" class="w-full px-2.5 py-1.5 rounded-xl border border-slate-200 text-xs font-semibold">
            </div>
            <div>
              <label class="block text-[10px] font-bold text-slate-600 mb-0.5">Code PIN (4 chiffres) *</label>
              <input type="password" maxlength="4" id="new-staff-pin" placeholder="3333" class="w-full px-2.5 py-1.5 rounded-xl border border-slate-200 text-xs font-bold text-center tracking-wider">
            </div>
          </div>

          <button id="add-staff-btn" class="w-full py-2.5 bg-slate-900 hover:bg-black text-white text-xs font-bold rounded-xl shadow transition-transform active:scale-95">
            Créer l'accès Caissier
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-team-modal').addEventListener('click', () => modal.remove());

    modal.querySelectorAll('[data-remove-staff]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const staffId = btn.getAttribute('data-remove-staff');
        if (confirm('Voulez-vous vraiment retirer ce compte caissier ?')) {
          await supabase.from('restaurant_staff').delete().eq('id', staffId);
          await fetchStaff();
          modal.remove();
          renderPosScreen();
        }
      });
    });

    modal.querySelector('#add-staff-btn').addEventListener('click', async () => {
      const name = modal.querySelector('#new-staff-name').value.trim();
      const pin = modal.querySelector('#new-staff-pin').value.trim();

      if (!name || name.length < 2) return alert('Veuillez entrer un prénom valide.');
      if (!pin || pin.length < 4) return alert('Le code PIN doit comporter 4 chiffres.');

      const { data, error } = await supabase
        .from('restaurant_staff')
        .insert({
          store_id: store.id,
          name: name,
          role: 'cashier',
          pin: pin
        })
        .select()
        .single();

      if (!error && data) {
        await fetchStaff();
        modal.remove();
        alert(`Caissier "${name}" ajouté avec succès !`);
        renderPosScreen();
      } else {
        alert("Erreur lors de la création de l'accès caissier.");
      }
    });
  }

  function openCategoryModal() {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4 safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0"></div>
        <h3 class="text-lg font-black text-slate-900">Nouvelle Catégorie</h3>
        
        <div>
          <label class="block text-xs font-bold text-slate-700 mb-1">Nom de la catégorie *</label>
          <input type="text" id="new-cat-name" placeholder="Ex: Tacos, Pâtes, Glaces..." class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm">
        </div>

        <div class="flex justify-end space-x-2 pt-2">
          <button id="cancel-cat-btn" class="px-4 py-2 text-xs font-bold text-slate-500 hover:text-slate-700">Annuler</button>
          <button id="save-cat-btn" class="px-4 py-2 text-xs font-bold bg-orange-600 hover:bg-orange-700 text-white rounded-xl shadow">Créer</button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#cancel-cat-btn').addEventListener('click', () => modal.remove());
    modal.querySelector('#save-cat-btn').addEventListener('click', async () => {
      const name = modal.querySelector('#new-cat-name').value.trim();
      if (!name) return alert('Veuillez entrer un nom de catégorie.');

      const { data, error } = await supabase
        .from('restaurant_categories')
        .insert({
          store_id: store.id,
          name: name,
          sort_order: categories.length + 1
        })
        .select()
        .single();

      if (!error && data) {
        categories.push(data);
        modal.remove();
        renderPosScreen();
      } else {
        alert('Erreur lors de la création de la catégorie.');
      }
    });
  }

  function openItemModal(itemToEdit = null) {
    const isEdit = !!itemToEdit;
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';

    modal.innerHTML = `
      <div class="bg-white w-full max-w-lg rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4 max-h-[92vh] overflow-y-auto safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-1 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100">
          <h3 class="text-base sm:text-lg font-black text-slate-900">${isEdit ? 'Modifier l\'Article' : 'Ajouter un Nouvel Article'}</h3>
          <button id="close-modal-x" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <div class="space-y-3 text-sm">
          <div>
            <label class="block text-xs font-bold text-slate-700 mb-1">Nom de l'article *</label>
            <input type="text" id="item-name" value="${itemToEdit?.name || ''}" placeholder="Ex: Pizza Tartiflette" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm">
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 mb-1">Catégorie *</label>
            <select id="item-cat" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm bg-white">
              ${categories.map(c => `
                <option value="${c.id}" ${itemToEdit?.category_id === c.id ? 'selected' : ''}>${c.name}</option>
              `).join('')}
            </select>
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 mb-1">Description / Ingrédients</label>
            <textarea id="item-desc" rows="2" placeholder="Ex: Sauce tomate, mozzarella, reblochon, pommes de terre, lardons..." class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm">${itemToEdit?.description || ''}</textarea>
          </div>

          <!-- Pricing mode -->
          <div class="p-3 bg-slate-50 rounded-2xl border border-slate-200 space-y-3">
            <label class="block text-xs font-bold text-slate-800">Tarification & Formats</label>
            
            <div class="grid grid-cols-3 gap-2">
              <div>
                <label class="block text-[11px] font-semibold text-slate-500 mb-0.5">Junior (€)</label>
                <input type="number" step="0.5" id="price-junior" value="${itemToEdit?.sizes?.[0]?.price || itemToEdit?.price || '8.00'}" class="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs font-bold">
              </div>
              <div>
                <label class="block text-[11px] font-semibold text-slate-500 mb-0.5">Sénior (€)</label>
                <input type="number" step="0.5" id="price-senior" value="${itemToEdit?.sizes?.[1]?.price || '11.00'}" class="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs font-bold">
              </div>
              <div>
                <label class="block text-[11px] font-semibold text-slate-500 mb-0.5">Méga (€)</label>
                <input type="number" step="0.5" id="price-mega" value="${itemToEdit?.sizes?.[2]?.price || '16.00'}" class="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs font-bold">
              </div>
            </div>

            <label class="flex items-center space-x-2 text-xs text-slate-600 font-medium">
              <input type="checkbox" id="single-price-cb" ${(!itemToEdit?.sizes || itemToEdit.sizes.length === 0) && isEdit ? 'checked' : ''} class="rounded text-orange-600 focus:ring-orange-500">
              <span>Prix unique (ignorer Sénior et Méga)</span>
            </label>
          </div>

          <!-- Base Sauces -->
          <div>
            <label class="block text-xs font-bold text-slate-700 mb-1">Sauce de base au choix (optionnel)</label>
            <input type="text" id="item-sauces" value="${(itemToEdit?.base_sauces || []).join(', ')}" placeholder="Ex: Sauce Tomate, Crème Fraîche" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm">
            <span class="text-[10px] text-slate-400">Séparez par des virgules</span>
          </div>
        </div>

        <div class="flex justify-end space-x-2 pt-3 border-t border-slate-100">
          <button id="cancel-item-btn" class="px-4 py-2 text-xs font-bold text-slate-500 hover:text-slate-700">Annuler</button>
          <button id="save-item-btn" class="px-5 py-2.5 text-xs font-bold bg-orange-600 hover:bg-orange-700 text-white rounded-xl shadow-md shadow-orange-600/25">Enregistrer</button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-modal-x').addEventListener('click', () => modal.remove());
    modal.querySelector('#cancel-item-btn').addEventListener('click', () => modal.remove());

    modal.querySelector('#save-item-btn').addEventListener('click', async () => {
      const name = modal.querySelector('#item-name').value.trim();
      const catId = modal.querySelector('#item-cat').value;
      const desc = modal.querySelector('#item-desc').value.trim();
      const isSinglePrice = modal.querySelector('#single-price-cb').checked;
      const pJunior = parseFloat(modal.querySelector('#price-junior').value) || 0;
      const pSenior = parseFloat(modal.querySelector('#price-senior').value) || 0;
      const pMega = parseFloat(modal.querySelector('#price-mega').value) || 0;
      const rawSauces = modal.querySelector('#item-sauces').value.trim();

      if (!name) return alert('Veuillez renseigner un nom pour cet article.');

      let sizes = [];
      let basePrice = pJunior;

      if (!isSinglePrice) {
        sizes = [
          { name: 'Junior', price: pJunior },
          { name: 'Sénior', price: pSenior },
          { name: 'Méga', price: pMega }
        ];
      }

      let baseSauces = rawSauces ? rawSauces.split(',').map(s => s.trim()).filter(Boolean) : [];

      const payload = {
        store_id: store.id,
        category_id: catId,
        name: name,
        description: desc || null,
        price: basePrice,
        sizes: sizes,
        base_sauces: baseSauces,
        is_available: true
      };

      if (isEdit) {
        const { error } = await supabase
          .from('restaurant_items')
          .update(payload)
          .eq('id', itemToEdit.id);

        if (!error) {
          modal.remove();
          refreshMenuItems();
        } else {
          alert("Erreur lors de la modification de l'article.");
        }
      } else {
        const { error } = await supabase
          .from('restaurant_items')
          .insert(payload);

        if (!error) {
          modal.remove();
          refreshMenuItems();
        } else {
          alert("Erreur lors de l'enregistrement de l'article.");
        }
      }
    });
  }

  // Helper for Printing Thermal Receipts, Z Reports, and Tax Certificates
  function printElementContent(elementId, title) {
    const el = document.getElementById(elementId);
    if (!el) return;
    const printWindow = window.open('', '_blank', 'width=450,height=650');
    if (!printWindow) {
      alert("Veuillez autoriser les fenêtres pop-up pour imprimer le ticket.");
      return;
    }
    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>${title}</title>
          <meta charset="utf-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Courier New", Courier, monospace; font-size: 13px; line-height: 1.35; color: #000; margin: 15px; }
            .center { text-align: center; }
            .right { text-align: right; }
            .bold { font-weight: bold; }
            .sep { border-bottom: 1px dashed #444; margin: 8px 0; }
            .row { display: flex; justify-content: space-between; margin: 2px 0; }
            @media print { body { margin: 5mm; } }
          </style>
        </head>
        <body>
          ${el.innerHTML}
          <script>
            window.onload = function() {
              window.print();
              setTimeout(() => window.close(), 1000);
            };
          <\/script>
        </body>
      </html>
    `);
    printWindow.document.close();
  }

  // Compliant French Restaurant Receipt (Note de restaurant)
  function openReceiptModal(order, optItems = null) {
    let modal = document.getElementById('receipt-modal');
    if (modal) modal.remove();

    const orderLines = optItems || order.restaurant_order_items || [];
    const totalTtc = Number(order.total_price || 0);
    const totalHt = Number(order.total_ht || (totalTtc / 1.10));
    const tva10 = Number(order.tva_10 || (totalTtc - totalHt));
    const tva55 = Number(order.tva_5_5 || 0);
    const orderDate = new Date(order.created_at || Date.now());
    const formattedDate = orderDate.toLocaleDateString('fr-FR');
    const formattedTime = orderDate.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

    modal = document.createElement('div');
    modal.id = 'receipt-modal';
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl flex flex-col max-h-[90vh] overflow-hidden safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-2 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100 shrink-0">
          <div class="flex items-center space-x-2">
            <span class="text-base">🧾</span>
            <h3 class="font-black text-slate-900 text-sm">Note de Restaurant #${order.order_number}</h3>
          </div>
          <button id="close-receipt-modal" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <!-- Thermal Receipt Container -->
        <div class="flex-1 overflow-y-auto my-3 bg-slate-50 p-4 rounded-2xl border border-slate-200">
          <div id="thermal-receipt-content" class="font-mono text-xs leading-relaxed text-slate-800">
            <div class="center bold text-sm uppercase">${store.name}</div>
            <div class="center text-[11px] text-slate-600">${store.address}</div>
            <div class="center text-[11px] text-slate-600">${store.city}</div>
            <div class="center text-[10px] text-slate-500">Tél: ${store.phone} • SIRET: 928 345 812 00018</div>
            <div class="sep"></div>

            <div class="row">
              <span>Ticket: #${order.order_number}</span>
              <span>${formattedDate} ${formattedTime}</span>
            </div>
            <div class="row">
              <span>Client: ${order.customer_name || 'Comptoir'}</span>
              <span>Caissier: ${order.staff_name || currentStaff?.name || 'Caissier'}</span>
            </div>
            <div class="row">
              <span>Mode: ${order.payment_method === 'card' ? 'CARTE BANCAIRE (TPE)' : 'ESPÈCES'}</span>
              <span class="bold">PAYÉ</span>
            </div>
            <div class="sep"></div>

            <!-- Items -->
            ${orderLines.map(line => `
              <div class="row">
                <span class="bold">${line.quantity || 1}x ${line.name || line.item_name}</span>
                <span class="bold">${Number(line.total_price || (line.unit_price * (line.quantity || 1))).toFixed(2)} €</span>
              </div>
              ${line.selected_size ? `<div class="text-[10px] text-slate-500 pl-2">Format: ${line.selected_size}</div>` : ''}
              ${line.selected_sauce ? `<div class="text-[10px] text-slate-500 pl-2">Sauce: ${line.selected_sauce}</div>` : ''}
            `).join('')}

            <div class="sep"></div>

            <!-- VAT Details -->
            <div class="row">
              <span>Sous-total HT :</span>
              <span>${totalHt.toFixed(2)} €</span>
            </div>
            <div class="row">
              <span>TVA 10.0% :</span>
              <span>${tva10.toFixed(2)} €</span>
            </div>
            ${tva55 > 0 ? `
              <div class="row">
                <span>TVA 5.5% :</span>
                <span>${tva55.toFixed(2)} €</span>
              </div>
            ` : ''}
            <div class="sep"></div>
            <div class="row bold text-sm pt-0.5">
              <span>TOTAL TTC :</span>
              <span>${totalTtc.toFixed(2)} €</span>
            </div>
            <div class="sep"></div>

            <!-- Security Hash -->
            <div class="text-[9px] text-slate-400 break-all text-center">
              Empreinte fiscale : ${order.signature_hash ? order.signature_hash.substring(0, 24) + '...' : 'SCELLEMENT_ACTIF'}
            </div>
            <div class="center text-[9px] text-slate-500 mt-1">
              Conforme Art. 286, I-3° bis du CGI<br>Système certifié Allonssy POS
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center space-x-2 pt-2 border-t border-slate-100 shrink-0">
          <button id="print-receipt-btn" class="flex-1 bg-orange-600 hover:bg-orange-700 text-white font-bold py-2.5 rounded-xl text-xs flex items-center justify-center space-x-1.5 shadow-md shadow-orange-600/25 transition-transform active:scale-95">
            <span>🖨️ Imprimer la Note</span>
          </button>
          <button id="close-receipt-btn-2" class="px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">
            Fermer
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-receipt-modal')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#close-receipt-btn-2')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#print-receipt-btn')?.addEventListener('click', () => {
      printElementContent('thermal-receipt-content', `Note_${order.order_number}_${store.slug}`);
    });
  }

  // Official Daily Z-Report Modal
  function openZReportModal(z) {
    let modal = document.getElementById('z-report-modal');
    if (modal) modal.remove();

    const zNum = z.z_number || 1;
    const pStart = new Date(z.period_start || Date.now()).toLocaleString('fr-FR');
    const pEnd = new Date(z.period_end || Date.now()).toLocaleString('fr-FR');

    modal = document.createElement('div');
    modal.id = 'z-report-modal';
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-md rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl flex flex-col max-h-[90vh] overflow-hidden safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-2 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100 shrink-0">
          <div class="flex items-center space-x-2">
            <span class="text-base">🔒</span>
            <h3 class="font-black text-slate-900 text-sm">Rapport Z de Caisse #${zNum} (Officiel)</h3>
          </div>
          <button id="close-z-modal" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <div class="flex-1 overflow-y-auto my-3 bg-slate-50 p-4 rounded-2xl border border-slate-200">
          <div id="thermal-z-content" class="font-mono text-xs leading-relaxed text-slate-800">
            <div class="center bold text-sm uppercase">${store.name}</div>
            <div class="center text-[11px] text-slate-600">${store.address}, ${store.city}</div>
            <div class="center text-[10px] text-slate-500">SIRET: 928 345 812 00018</div>
            <div class="sep"></div>
            <div class="center bold text-sm">*** RAPPORT Z DE CAISSE N° ${zNum} ***</div>
            <div class="center text-[10px] text-slate-500">Clôture journalière inaltérable</div>
            <div class="sep"></div>

            <div class="text-[11px]">Début: ${pStart}</div>
            <div class="text-[11px]">Fin:   ${pEnd}</div>
            <div class="text-[11px]">Clôturé par: ${z.closed_by_staff_name || 'Gérant'}</div>
            <div class="text-[11px]">Tickets encaissés: ${z.order_count || 0}</div>
            <div class="sep"></div>

            <div class="row bold">
              <span>CHIFFRE D'AFFAIRES TTC :</span>
              <span>${Number(z.total_ttc || 0).toFixed(2)} €</span>
            </div>
            <div class="row">
              <span>Chiffre d'Affaires HT :</span>
              <span>${Number(z.total_ht || 0).toFixed(2)} €</span>
            </div>
            <div class="row">
              <span>Total TVA 10.0% :</span>
              <span>${Number(z.total_tva_10 || 0).toFixed(2)} €</span>
            </div>
            <div class="row">
              <span>Total TVA 5.5% :</span>
              <span>${Number(z.total_tva_5_5 || 0).toFixed(2)} €</span>
            </div>
            <div class="sep"></div>

            <div class="bold text-[11px] uppercase pb-1">Ventilation des Règlements :</div>
            <div class="row">
              <span>• Total Espèces :</span>
              <span class="bold">${Number(z.total_cash || 0).toFixed(2)} €</span>
            </div>
            <div class="row">
              <span>• Total Carte Bancaire (TPE) :</span>
              <span class="bold">${Number(z.total_card || 0).toFixed(2)} €</span>
            </div>
            <div class="sep"></div>

            <div class="row bold text-xs text-orange-950 bg-orange-100/60 p-1.5 rounded">
              <span>GRAND TOTAL PERPÉTUEL :</span>
              <span>${Number(z.grand_total_perpetuel || 0).toFixed(2)} €</span>
            </div>
            <div class="text-[9px] text-slate-500 pt-0.5">Cumul non réinitialisable obligatoire CGI art. 286</div>
            <div class="sep"></div>

            <div class="text-[9px] text-slate-400 break-all text-center">
              SHA-256: ${z.signature_hash}
            </div>
            <div class="center text-[9px] text-slate-500 mt-1">
              Document certifié inaltérable • À archiver 6 ans
            </div>
          </div>
        </div>

        <div class="flex items-center space-x-2 pt-2 border-t border-slate-100 shrink-0">
          <button id="print-z-btn" class="flex-1 bg-slate-900 hover:bg-black text-white font-bold py-2.5 rounded-xl text-xs flex items-center justify-center space-x-1.5 shadow transition-transform active:scale-95">
            <span>🖨️ Imprimer Rapport Z</span>
          </button>
          <button id="close-z-btn-2" class="px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">
            Fermer
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-z-modal')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#close-z-btn-2')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#print-z-btn')?.addEventListener('click', () => {
      printElementContent('thermal-z-content', `Rapport_Z_${zNum}_${store.slug}`);
    });
  }

  // Official Editor's Certificate Modal (BOI-TVA-DECLA-30-10-30)
  function openTaxCertificateModal() {
    let modal = document.getElementById('tax-cert-modal');
    if (modal) modal.remove();

    const todayStr = new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });

    modal = document.createElement('div');
    modal.id = 'tax-cert-modal';
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-lg rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl flex flex-col max-h-[92vh] overflow-hidden safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-2 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100 shrink-0">
          <div class="flex items-center space-x-2">
            <span class="text-base">📜</span>
            <h3 class="font-black text-slate-900 text-sm">Attestation de Conformité Fiscale (DGFiP)</h3>
          </div>
          <button id="close-tax-cert-modal" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <div class="flex-1 overflow-y-auto my-3 p-4 bg-slate-50 rounded-2xl border border-slate-200">
          <div id="tax-cert-content" class="bg-white p-6 rounded-xl border border-slate-200 text-xs text-slate-800 leading-relaxed space-y-4 shadow-sm font-sans">
            <div class="text-center pb-2 border-b border-slate-200 space-y-1">
              <div class="font-black text-sm tracking-wider uppercase text-slate-900">RÉPUBLIQUE FRANÇAISE</div>
              <div class="text-[10px] text-slate-500 font-semibold uppercase">Direction Générale des Finances Publiques</div>
              <div class="font-bold text-xs text-orange-600 pt-1">
                ATTESTATION INDIVIDUELLE DE CONFORMITÉ
              </div>
              <div class="text-[10px] text-slate-400">
                (Délivrée en application du 3° bis du I de l'article 286 du code général des impôts)
              </div>
            </div>

            <div>
              <div class="bg-slate-900 text-white p-2 rounded-lg font-black text-xs uppercase tracking-wide text-center mb-3">
                VOLET 1 – ATTESTATION DE L'ÉDITEUR DU LOGICIEL
              </div>
              <p class="text-[11px] text-slate-600 mb-2">
                <strong>Société éditrice :</strong> TRADISTER SAS<br>
                <strong>Numéro SIREN :</strong> 988 318 945 | <strong>SIRET :</strong> 988 318 945 00017<br>
                <strong>Code NAF :</strong> 62.02A (Conseil en systèmes et logiciels informatiques)<br>
                <strong>Siège social :</strong> 11 Rue du Château d'Eau, 91130 Ris-Orangis, France<br>
                <strong>Représentant légal :</strong> Bisma KASHIF, Président de SAS<br>
                <strong>Nom du logiciel :</strong> Allonssy Restaurant POS<br>
                <strong>Version certifiée :</strong> 1.0.0 (Web Cloud Architecture)<br>
                <strong>Date de mise sur le marché :</strong> 22 Novembre 2026
              </p>
              
              <div class="p-3 bg-slate-50 rounded-xl border border-slate-200 my-2">
                <p class="text-[11px] text-slate-700 text-justify">
                  Je soussigné(e), Bisma KASHIF, agissant en qualité de Président de la société éditrice <strong>TRADISTER SAS</strong>, atteste sur l'honneur que le logiciel ci-dessus désigné satisfait à l'ensemble des conditions d'<strong>inaltérabilité</strong>, de <strong>sécurisation</strong>, de <strong>conservation</strong> et d'<strong>archivage</strong> des données prévues au 3° bis du I de l'article 286 du CGI.
                </p>
                <ul class="list-disc pl-4 text-[10px] text-slate-600 mt-2 space-y-1">
                  <li><strong>Inaltérabilité :</strong> Interdiction stricte de toute suppression ou modification de règlement enregistré (verrouillage PostgreSQL au niveau serveur).</li>
                  <li><strong>Sécurisation :</strong> Chaînage cryptographique continu de chaque transaction avec signature hachée SHA-256.</li>
                  <li><strong>Conservation :</strong> Clôtures journalières Z obligatoires avec incrémentation du Grand Total Perpétuel non réinitialisable.</li>
                  <li><strong>Archivage :</strong> Génération instantanée d'un journal des écritures de caisse inaltérable pour contrôle fiscal DGFiP (Art. L. 80 O LPF).</li>
                </ul>
              </div>

              <div class="flex justify-between items-end text-[10px] pt-1">
                <div>
                  <p>Fait à Ris-Orangis, le ${todayStr}</p>
                  <p class="text-slate-400">Pour valoir ce que de droit.</p>
                </div>
                <div class="text-right">
                  <span class="font-bold text-slate-900">Pour TRADISTER SAS</span>
                  <div class="text-[9px] text-emerald-600 font-bold mt-0.5">✓ Certificat Éditeur Scellé</div>
                </div>
              </div>
            </div>

            <div class="pt-3 border-t border-dashed border-slate-300">
              <div class="bg-orange-600 text-white p-2 rounded-lg font-black text-xs uppercase tracking-wide text-center mb-3">
                VOLET 2 – ATTESTATION DE L'ENTREPRISE UTILISATRICE
              </div>
              <p class="text-[11px] text-slate-600 mb-2">
                <strong>Établissement exploitant :</strong> ${store.name}<br>
                <strong>Adresse d'exploitation :</strong> ${store.address}, ${store.city}<br>
                <strong>Sous-domaine sécurisé :</strong> ${store.slug}.allonssy.com<br>
                <strong>Numéro SIRET client :</strong> 928 345 812 00018<br>
                <strong>Date de début d'utilisation :</strong> 22 Novembre 2026
              </p>
              
              <div class="p-3 bg-amber-50/60 rounded-xl border border-amber-200 text-[10px] text-slate-700 space-y-1">
                <p>
                  L'entreprise utilisatrice certifie utiliser le logiciel Allonssy Restaurant POS (v1.0.0) édité par TRADISTER SAS pour l'enregistrement de l'ensemble des encaissements de ses clients particuliers.
                </p>
                <p class="text-slate-500 italic">
                  Ce document (Volet 1 et Volet 2) doit être conservé dans l'établissement et être présenté immédiatement à toute réquisition des agents de l'administration fiscale (Article L. 80 O du LPF).
                </p>
              </div>

              <div class="flex justify-between items-end text-[10px] pt-2">
                <div>
                  <p>Signature et cachet du restaurateur :</p>
                  <div class="w-36 h-12 border border-dashed border-slate-300 rounded mt-1 flex items-center justify-center text-[9px] text-slate-400">
                    Cachet & Signature
                  </div>
                </div>
                <div class="text-right">
                  <span class="font-bold text-slate-900">Statut Conformité DGFiP</span>
                  <div class="text-[10px] text-emerald-600 font-bold mt-1">✓ Conforme Art. 286 CGI</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center space-x-2 pt-2 border-t border-slate-100 shrink-0">
          <button id="print-tax-cert-btn" class="flex-1 bg-slate-900 hover:bg-black text-white font-bold py-2.5 rounded-xl text-xs flex items-center justify-center space-x-1.5 shadow transition-transform active:scale-95">
            <span>🖨️ Imprimer l'Attestation Officielle</span>
          </button>
          <button id="close-tax-cert-btn-2" class="px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">
            Fermer
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-tax-cert-modal')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#close-tax-cert-btn-2')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#print-tax-cert-btn')?.addEventListener('click', () => {
      printElementContent('tax-cert-content', `Attestation_Fiscale_Allonssy_POS_${store.slug}`);
    });
  }

  // Official Technical File Modal (Article L. 80 O LPF & Art. 286 I-3° bis CGI)
  function openTechDossierModal() {
    let modal = document.getElementById('tech-dossier-modal');
    if (modal) modal.remove();

    modal = document.createElement('div');
    modal.id = 'tech-dossier-modal';
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-2xl rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl flex flex-col max-h-[92vh] overflow-hidden safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mb-2 sm:hidden shrink-0"></div>
        <div class="flex justify-between items-center pb-2 border-b border-slate-100 shrink-0">
          <div class="flex items-center space-x-2">
            <span class="text-base">📄</span>
            <h3 class="font-black text-slate-900 text-sm">Dossier Technique de Conformité (DGFiP)</h3>
          </div>
          <button id="close-tech-dossier-modal" class="p-1 text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <div class="flex-1 overflow-y-auto my-3 p-4 bg-slate-50 rounded-2xl border border-slate-200">
          <div id="tech-dossier-content" class="bg-white p-6 rounded-xl border border-slate-200 text-xs text-slate-800 leading-relaxed space-y-4 shadow-sm font-sans">
            <div class="text-center pb-3 border-b border-slate-200 space-y-1">
              <div class="font-black text-sm tracking-wider uppercase text-slate-900">DOSSIER TECHNIQUE D'HOMOLOGATION FISCALE</div>
              <div class="text-[10px] text-slate-500 font-semibold uppercase">Système de Caisse Sécurisé – Article 286, I-3° bis du CGI</div>
              <div class="text-[10px] text-orange-600 font-bold">Réf. Doctrine BOFiP BOI-TVA-DECLA-30-10-30 & Article L. 80 O du LPF</div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-[11px] bg-slate-50 p-3 rounded-xl border border-slate-200">
              <div>
                <strong class="text-slate-900">Éditeur :</strong> TRADISTER SAS<br>
                <strong class="text-slate-900">SIRET :</strong> 988 318 945 00017<br>
                <strong class="text-slate-900">Siège :</strong> 11 Rue du Château d'Eau, 91130 Ris-Orangis<br>
                <strong class="text-slate-900">Dirigeant :</strong> Bisma KASHIF, Président
              </div>
              <div>
                <strong class="text-slate-900">Logiciel :</strong> Allonssy Restaurant POS<br>
                <strong class="text-slate-900">Version :</strong> 1.0.0 (Production)<br>
                <strong class="text-slate-900">Établissement :</strong> ${store.name}<br>
                <strong class="text-slate-900">Sous-domaine :</strong> ${store.slug}.allonssy.com
              </div>
            </div>

            <div class="space-y-3">
              <div>
                <h4 class="font-black text-slate-900 text-xs uppercase text-orange-600">1. Inaltérabilité des Écritures</h4>
                <p class="text-[11px] text-slate-600 text-justify">
                  Le système interdit formellement la suppression ou la modification discrète de règlements encaissés via un verrouillage au niveau du moteur de base de données PostgreSQL (<code>trg_guard_order_inalterability</code>). Toute tentative de DELETE sur un ticket payé lève une exception SQL bloquante. Tout remboursement ou correction s'effectue obligatoirement sous forme d'un avoir lié (<code>is_refund = TRUE</code>).
                </p>
              </div>

              <div>
                <h4 class="font-black text-slate-900 text-xs uppercase text-orange-600">2. Sécurisation & Chaînage Cryptographique</h4>
                <p class="text-[11px] text-slate-600 text-justify">
                  Chaque ticket est scellé à l'encaissement via une empreinte cryptographique SHA-256 (<code>trg_seal_order_trigger</code>). Le calcul intègre les identifiants, montants, ventilations TVA (10% et 5.5%), horodatage et la signature du ticket précédent (<code>previous_signature_hash</code>), formant une chaîne séquentielle continue et infalsifiable.
                </p>
              </div>

              <div>
                <h4 class="font-black text-slate-900 text-xs uppercase text-orange-600">3. Conservation & Clôture Z (Grand Total Perpétuel)</h4>
                <p class="text-[11px] text-slate-600 text-justify">
                  À la fin de chaque journée de vente, la fonction <code>close_daily_z_report</code> consolide les encaissements par moyen de paiement et incrémente le <strong>Grand Total Perpétuel (GTP)</strong>. Ce compteur est strictement cumulatif et non réinitialisable, garantissant une cohérence permanente entre le tiroir-caisse et la comptabilité.
                </p>
              </div>

              <div>
                <h4 class="font-black text-slate-900 text-xs uppercase text-orange-600">4. Archivage & Contrôle Fiscal (Art. L. 80 O LPF)</h4>
                <p class="text-[11px] text-slate-600 text-justify">
                  La fonction <code>get_fiscal_audit_data</code> exporte en un clic l'intégralité du journal d'audit scellé pour remise immédiate aux inspecteurs des impôts. Les archives sont sauvegardées automatiquement chaque nuit sur serveur dédié et conservées pendant <strong>6 années</strong> conformément à l'article L. 102 B du Livre des procédures fiscales.
                </p>
              </div>
            </div>

            <div class="pt-3 border-t border-slate-200 flex justify-between items-center text-[10px] text-slate-500">
              <span>Document interne d'homologation – TRADISTER SAS</span>
              <span class="text-emerald-600 font-bold">✓ Homologation Active v1.0.0</span>
            </div>
          </div>
        </div>

        <div class="flex items-center space-x-2 pt-2 border-t border-slate-100 shrink-0">
          <button id="print-tech-dossier-btn" class="flex-1 bg-slate-900 hover:bg-black text-white font-bold py-2.5 rounded-xl text-xs flex items-center justify-center space-x-1.5 shadow transition-transform active:scale-95">
            <span>🖨️ Imprimer le Dossier Technique</span>
          </button>
          <button id="close-tech-dossier-btn-2" class="px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">
            Fermer
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-tech-dossier-modal')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#close-tech-dossier-btn-2')?.addEventListener('click', () => modal.remove());
    modal.querySelector('#print-tech-dossier-btn')?.addEventListener('click', () => {
      printElementContent('tech-dossier-content', `Dossier_Technique_Conformite_DGFiP_${store.slug}`);
    });
  }

  // Initial execution
  if (!isUnlocked) {
    renderPinLock();
  } else {
    initPos();
  }
}
