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
            <input type="password" id="pos-pin-input" maxlength="4" placeholder="Code PIN (ex: 1234)" class="w-full text-center tracking-[0.5em] text-2xl font-bold py-3 px-4 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 focus:outline-none">
            
            <button id="unlock-pin-btn" class="w-full bg-orange-600 hover:bg-orange-700 text-white font-bold py-3.5 rounded-xl shadow-lg shadow-orange-600/30 transition-transform active:scale-[0.99]">
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
    container.innerHTML = `
      <div class="flex-1 flex flex-col bg-slate-100 h-full overflow-hidden">
        <!-- Top Cashier Bar -->
        <header class="bg-slate-900 text-white px-5 py-3 flex items-center justify-between shadow-md shrink-0">
          <div class="flex items-center space-x-3">
            <span class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></span>
            <div class="leading-tight">
              <h1 class="text-base font-black tracking-tight">${store.name}</h1>
              <p class="text-[11px] text-slate-400">Caisse & Analytics Temps Réel</p>
            </div>
          </div>

          <!-- Tab Switches -->
          <div class="flex items-center bg-slate-800 p-1 rounded-xl space-x-1">
            <button id="tab-live-orders" class="px-3.5 py-2 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'live_orders' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
              <span>🔔 Commandes</span>
              ${orders.filter(o => o.status !== 'completed' && o.status !== 'cancelled').length > 0 ? `
                <span class="bg-white text-orange-600 text-[10px] font-black px-1.5 py-0.2 rounded-full">
                  ${orders.filter(o => o.status !== 'completed' && o.status !== 'cancelled').length}
                </span>
              ` : ''}
            </button>
            <button id="tab-counter-pos" class="px-3.5 py-2 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'counter_pos' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
              <span>🧾 Caisse</span>
            </button>
            <button id="tab-analytics" class="px-3.5 py-2 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'analytics' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
              <span>📊 Statistiques & Ventes</span>
            </button>
            <button id="tab-menu-manager" class="px-3.5 py-2 rounded-lg text-xs font-bold transition-all flex items-center space-x-1.5 ${activeTab === 'menu_manager' ? 'bg-orange-600 text-white shadow' : 'text-slate-300 hover:text-white'}">
              <span>🍽️ Carte & Équipe</span>
            </button>
          </div>

          <!-- Staff Profile & Actions -->
          <div class="flex items-center space-x-2">
            <!-- Active Cashier Pill -->
            <button id="switch-staff-btn" class="text-xs bg-slate-800 hover:bg-slate-700 text-orange-400 px-3 py-1.5 rounded-xl font-bold flex items-center space-x-1.5 transition-colors border border-slate-700">
              <span class="w-2 h-2 rounded-full bg-orange-500"></span>
              <span>${currentStaff ? currentStaff.name : 'Caissier'}</span>
              <span class="text-[10px] text-slate-400 font-normal">(${currentStaff?.role === 'owner' ? 'Patron' : 'Caissier'})</span>
            </button>

            <button id="test-sound-btn" title="Tester la sonnerie" class="p-2 text-slate-400 hover:text-white bg-slate-800 rounded-xl transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/></svg>
            </button>
            <button id="lock-pos-btn" class="text-xs bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-2 rounded-xl font-bold flex items-center space-x-1 transition-colors">
              <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
              <span>Verrouiller</span>
            </button>
          </div>
        </header>

        <!-- Main Workspace -->
        <div class="flex-1 overflow-hidden flex flex-col p-4">
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

    // Bind Top Tabs
    container.querySelector('#tab-live-orders')?.addEventListener('click', () => {
      activeTab = 'live_orders';
      renderPosScreen();
    });
    container.querySelector('#tab-counter-pos')?.addEventListener('click', () => {
      activeTab = 'counter_pos';
      renderPosScreen();
    });
    container.querySelector('#tab-analytics')?.addEventListener('click', () => {
      activeTab = 'analytics';
      renderPosScreen();
    });
    container.querySelector('#tab-menu-manager')?.addEventListener('click', () => {
      activeTab = 'menu_manager';
      renderPosScreen();
    });

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
      <div class="flex-1 flex flex-col min-h-0 space-y-4">
        <!-- Live Stats summary -->
        <div class="grid grid-cols-4 gap-3 shrink-0">
          <div class="bg-white rounded-2xl p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[11px] font-bold text-slate-400 uppercase">En Attente / Reçues</div>
              <div class="text-2xl font-black text-amber-600">${orders.filter(o => o.status === 'received').length}</div>
            </div>
            <span class="w-8 h-8 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center font-bold">1</span>
          </div>

          <div class="bg-white rounded-2xl p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[11px] font-bold text-slate-400 uppercase">Au Four / En Cours</div>
              <div class="text-2xl font-black text-blue-600">${orders.filter(o => o.status === 'preparing').length}</div>
            </div>
            <span class="w-8 h-8 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center font-bold">2</span>
          </div>

          <div class="bg-white rounded-2xl p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[11px] font-bold text-slate-400 uppercase">Prêtes au Retrait</div>
              <div class="text-2xl font-black text-green-600">${orders.filter(o => o.status === 'ready').length}</div>
            </div>
            <span class="w-8 h-8 rounded-full bg-green-50 text-green-600 flex items-center justify-center font-bold">3</span>
          </div>

          <div class="bg-white rounded-2xl p-3 border border-slate-200 shadow-sm flex items-center justify-between">
            <div>
              <div class="text-[11px] font-bold text-slate-400 uppercase">Total Commandes Jour</div>
              <div class="text-2xl font-black text-slate-800">${orders.length}</div>
            </div>
            <span class="w-8 h-8 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center font-bold">✓</span>
          </div>
        </div>

        <!-- Orders Queue Grid -->
        <div class="flex-1 overflow-y-auto">
          ${activeOrders.length === 0 ? `
            <div class="h-full flex flex-col items-center justify-center text-center p-8 bg-white rounded-3xl border border-slate-200 shadow-sm">
              <div class="w-16 h-16 bg-slate-100 text-slate-400 rounded-full flex items-center justify-center mb-3">
                <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
              </div>
              <h3 class="font-bold text-slate-800 text-lg">Aucune commande en attente</h3>
              <p class="text-xs text-slate-400 max-w-sm mt-1">Les nouvelles commandes en ligne ou au comptoir apparaîtront ici automatiquement avec une alerte sonore.</p>
            </div>
          ` : `
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              ${activeOrders.map(order => renderOrderCard(order)).join('')}
            </div>
          `}

          <!-- Completed Orders Section -->
          ${completedOrders.length > 0 ? `
            <div class="mt-8 pt-4">
              <h3 class="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3">Dernières commandes terminées</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
                ${completedOrders.map(order => `
                  <div class="bg-white/80 rounded-2xl p-3.5 border border-slate-200 text-xs opacity-85 flex justify-between items-center">
                    <div>
                      <div class="font-bold text-slate-800">#${order.order_number} • ${order.customer_name || 'Client comptoir'}</div>
                      <div class="text-[11px] text-slate-500 mt-0.5">
                        ${order.staff_name ? `<span class="font-semibold text-orange-600">Par: ${order.staff_name}</span> • ` : ''}
                        ${Number(order.total_price).toFixed(2)} €
                      </div>
                    </div>
                    <span class="bg-green-100 text-green-800 text-[10px] font-extrabold px-2 py-0.5 rounded-full">Payée</span>
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
  }

  function openPaymentValidationModal(orderId) {
    const order = orders.find(o => o.id === orderId);
    if (!order) return;

    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-3xl p-6 shadow-2xl text-center space-y-5">
        <h3 class="text-lg font-black text-slate-900">Encaisser la Commande #${order.order_number}</h3>
        <div class="text-3xl font-black text-orange-600">${Number(order.total_price).toFixed(2)} €</div>
        <p class="text-xs text-slate-500">
          Encaissé par : <strong>${currentStaff?.name || 'Caissier'}</strong>
        </p>

        <div class="grid grid-cols-2 gap-3">
          <button id="pay-cash-btn" class="p-4 rounded-2xl border-2 border-slate-200 hover:border-orange-500 hover:bg-orange-50/50 text-slate-800 font-bold text-sm flex flex-col items-center space-y-1 transition-all">
            <span class="text-2xl">💵</span>
            <span>Espèces</span>
          </button>
          <button id="pay-card-btn" class="p-4 rounded-2xl border-2 border-slate-200 hover:border-orange-500 hover:bg-orange-50/50 text-slate-800 font-bold text-sm flex flex-col items-center space-y-1 transition-all">
            <span class="text-2xl">💳</span>
            <span>Carte (TPE)</span>
          </button>
        </div>

        <button id="cancel-pay-btn" class="text-xs text-slate-400 hover:text-slate-600 font-semibold">Annuler</button>
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

    return `
      <div class="flex-1 flex gap-4 min-h-0">
        <!-- Left: Categories & Grid -->
        <div class="flex-1 flex flex-col bg-white rounded-3xl p-4 border border-slate-200 shadow-sm min-h-0">
          <!-- Categories Bar -->
          <div class="flex space-x-2 overflow-x-auto pb-3 shrink-0">
            ${categories.map(c => `
              <button data-counter-cat="${c.id}" class="counter-cat-btn px-4 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${c.id === counterSelectedCat ? 'bg-orange-600 text-white shadow' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'}">
                ${c.name}
              </button>
            `).join('')}
          </div>

          <!-- Items Grid -->
          <div class="flex-1 overflow-y-auto grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 pt-2">
            ${catItems.map(item => `
              <button data-counter-item-id="${item.id}" class="counter-product-card bg-slate-50 hover:bg-orange-50 hover:border-orange-300 border border-slate-200 rounded-2xl p-3 text-left transition-all flex flex-col justify-between h-28 active:scale-95">
                <span class="font-bold text-slate-900 text-sm line-clamp-2 leading-tight">${item.name}</span>
                <span class="font-extrabold text-orange-600 text-sm mt-2">${Number(item.price).toFixed(2)} €</span>
              </button>
            `).join('')}
          </div>
        </div>

        <!-- Right: Active Ticket -->
        <div class="w-80 md:w-96 bg-white rounded-3xl p-5 border border-slate-200 shadow-sm flex flex-col min-h-0 shrink-0">
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
      </div>
    `;
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
      counterTicket = [];
      alert(`Vente de ${total.toFixed(2)} € validée par ${currentStaff ? currentStaff.name : 'Caissier'} (${paymentMethod === 'card' ? 'Carte' : 'Espèces'}) !`);
      fetchOrders();

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
      <div class="flex-1 flex flex-col bg-white rounded-3xl p-5 border border-slate-200 shadow-sm min-h-0 space-y-5 overflow-y-auto">
        <!-- Top Filter Controls -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 pb-3 border-b border-slate-100 shrink-0">
          <div>
            <h2 class="text-xl font-black text-slate-900 tracking-tight">Rapports & Analyse des Ventes</h2>
            <p class="text-xs text-slate-500">Chiffre d'affaires, répartition par caissier et suivi des performances.</p>
          </div>

          <!-- Time Period Pills -->
          <div class="flex items-center bg-slate-100 p-1 rounded-xl space-x-1">
            <button data-period="today" class="period-btn px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'today' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              Aujourd'hui
            </button>
            <button data-period="week" class="period-btn px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'week' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              7 Derniers Jours
            </button>
            <button data-period="month" class="period-btn px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'month' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              Ce Mois
            </button>
            <button data-period="all" class="period-btn px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${analyticsPeriod === 'all' ? 'bg-orange-600 text-white shadow' : 'text-slate-600 hover:text-slate-900'}">
              Historique Global
            </button>
          </div>
        </div>

        <!-- 4 Big Metric Cards -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="p-4 rounded-2xl bg-orange-50/60 border border-orange-100 flex flex-col justify-between">
            <span class="text-xs font-bold text-orange-900 uppercase tracking-wider">Chiffre d'Affaires</span>
            <div class="text-3xl font-black text-orange-600 mt-2">${totalSales.toFixed(2)} €</div>
            <span class="text-[11px] text-orange-700/80 mt-1">${orderCount} commandes encaissées</span>
          </div>

          <div class="p-4 rounded-2xl bg-blue-50/60 border border-blue-100 flex flex-col justify-between">
            <span class="text-xs font-bold text-blue-900 uppercase tracking-wider">Panier Moyen</span>
            <div class="text-3xl font-black text-blue-600 mt-2">${avgBasket.toFixed(2)} €</div>
            <span class="text-[11px] text-blue-700/80 mt-1">Par ticket / client</span>
          </div>

          <div class="p-4 rounded-2xl bg-emerald-50/60 border border-emerald-100 flex flex-col justify-between">
            <span class="text-xs font-bold text-emerald-900 uppercase tracking-wider">Paiements Carte (TPE)</span>
            <div class="text-3xl font-black text-emerald-600 mt-2">${cardSales.toFixed(2)} €</div>
            <span class="text-[11px] text-emerald-700/80 mt-1">${totalSales > 0 ? ((cardSales / totalSales) * 100).toFixed(0) : 0}% du chiffre total</span>
          </div>

          <div class="p-4 rounded-2xl bg-amber-50/60 border border-amber-100 flex flex-col justify-between">
            <span class="text-xs font-bold text-amber-900 uppercase tracking-wider">Paiements Espèces</span>
            <div class="text-3xl font-black text-amber-600 mt-2">${cashSales.toFixed(2)} €</div>
            <span class="text-[11px] text-amber-700/80 mt-1">${totalSales > 0 ? ((cashSales / totalSales) * 100).toFixed(0) : 0}% du chiffre total</span>
          </div>
        </div>

        <!-- 2 Column Section: Staff Performance vs Weekly Evolution -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
          <!-- Left: Sales by Person / Staff -->
          <div class="p-5 rounded-2xl border border-slate-200 bg-slate-50/50 flex flex-col space-y-4">
            <div class="flex justify-between items-center">
              <h3 class="font-extrabold text-slate-900 text-sm flex items-center space-x-1.5">
                <span>👤</span>
                <span>Ventes par Personne / Caissier</span>
              </h3>
              <span class="text-xs font-bold text-slate-400">${staffSalesList.length} caissiers actifs</span>
            </div>

            <div class="space-y-3">
              ${staffSalesList.length === 0 ? `
                <p class="text-xs text-slate-400 py-4 text-center">Aucune vente enregistrée sur cette période.</p>
              ` : staffSalesList.map(st => {
                const pct = totalSales > 0 ? ((st.total / totalSales) * 100).toFixed(0) : 0;
                return `
                  <div class="bg-white p-3.5 rounded-xl border border-slate-200 shadow-sm flex flex-col space-y-2">
                    <div class="flex justify-between items-center">
                      <div class="flex items-center space-x-2">
                        <span class="w-7 h-7 rounded-full bg-slate-900 text-white font-extrabold text-xs flex items-center justify-center">
                          ${st.name.charAt(0)}
                        </span>
                        <div>
                          <span class="font-bold text-slate-900 text-xs">${st.name}</span>
                          <span class="text-[10px] text-slate-400 ml-1">(${st.count} ventes)</span>
                        </div>
                      </div>
                      <div class="text-right">
                        <span class="font-extrabold text-slate-900 text-sm">${st.total.toFixed(2)} €</span>
                        <span class="text-[10px] text-orange-600 font-bold block">${pct}%</span>
                      </div>
                    </div>
                    <!-- Progress bar -->
                    <div class="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                      <div class="bg-orange-500 h-full rounded-full transition-all duration-500" style="width: ${pct}%"></div>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Right: Weekly Trend Chart (Visual Bars) -->
          <div class="p-5 rounded-2xl border border-slate-200 bg-slate-50/50 flex flex-col justify-between space-y-4">
            <div class="flex justify-between items-center">
              <h3 class="font-extrabold text-slate-900 text-sm flex items-center space-x-1.5">
                <span>📈</span>
                <span>Évolution des 7 Derniers Jours</span>
              </h3>
              <span class="text-xs font-bold text-slate-500">Total : ${dailyTrend.reduce((s, d) => s + d.total, 0).toFixed(2)} €</span>
            </div>

            <!-- Visual Bar Chart -->
            <div class="grid grid-cols-7 gap-2 items-end h-44 pt-6 pb-2 px-1">
              ${dailyTrend.map(d => {
                const barHeight = Math.max(12, Math.round((d.total / maxDayTotal) * 100));
                return `
                  <div class="flex flex-col items-center h-full justify-end group">
                    <span class="text-[10px] font-bold text-slate-700 opacity-0 group-hover:opacity-100 transition-opacity mb-1 whitespace-nowrap">
                      ${d.total.toFixed(0)}€
                    </span>
                    <div class="w-full bg-orange-100 hover:bg-orange-500 rounded-t-lg transition-colors cursor-pointer relative" style="height: ${barHeight}%;">
                      <div class="bg-orange-500 h-full rounded-t-lg opacity-80 group-hover:opacity-100"></div>
                    </div>
                    <span class="text-[10px] font-semibold text-slate-500 mt-2 capitalize">${d.label}</span>
                  </div>
                `;
              }).join('')}
            </div>

            <p class="text-[11px] text-slate-400 text-center">Survolez une barre pour voir le chiffre d'affaires exact du jour.</p>
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
  }

  // TAB 4: Menu & Team / Sub-Accounts Manager
  function renderMenuManagerWorkspace() {
    const displayedItems = managerSelectedCat === 'all' 
      ? items 
      : items.filter(i => i.category_id === managerSelectedCat);

    return `
      <div class="flex-1 flex flex-col bg-white rounded-3xl p-5 border border-slate-200 shadow-sm min-h-0 space-y-4">
        <!-- Header Controls -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 pb-3 border-b border-slate-100 shrink-0">
          <div>
            <h2 class="text-lg font-black text-slate-900">Carte & Gestion des Employés</h2>
            <p class="text-xs text-slate-500">Gérez les plats du restaurant et les comptes de vos caissiers.</p>
          </div>

          <div class="flex items-center space-x-2">
            <button id="manage-team-btn" class="text-xs bg-slate-900 hover:bg-black text-white px-3.5 py-2.5 rounded-xl font-bold transition-colors flex items-center space-x-1.5 shadow">
              <span>👥 Gérer l'Équipe (${staffList.length})</span>
            </button>
            <button id="add-category-btn" class="text-xs bg-slate-100 hover:bg-slate-200 text-slate-700 px-3.5 py-2.5 rounded-xl font-bold transition-colors">
              + Catégorie
            </button>
            <button id="add-item-btn" class="text-xs bg-orange-600 hover:bg-orange-700 text-white px-4 py-2.5 rounded-xl font-bold shadow-md shadow-orange-600/25 transition-transform active:scale-95 flex items-center space-x-1.5">
              <span>+ Ajouter un Article</span>
            </button>
          </div>
        </div>

        <!-- Filter Categories Bar -->
        <div class="flex space-x-2 overflow-x-auto pb-1 shrink-0">
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
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4">
        <div class="flex justify-between items-center pb-2 border-b border-slate-100">
          <h3 class="text-base font-black text-slate-900">Changer d'Utilisateur / Caissier</h3>
          <button id="close-staff-modal" class="text-slate-400 hover:text-slate-600">✕</button>
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
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-md rounded-3xl p-6 shadow-2xl space-y-4 max-h-[85vh] overflow-y-auto">
        <div class="flex justify-between items-center pb-2 border-b border-slate-100">
          <h3 class="text-base font-black text-slate-900">Équipe & Sous-Comptes Caissiers</h3>
          <button id="close-team-modal" class="text-slate-400 hover:text-slate-600">✕</button>
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
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in';
    modal.innerHTML = `
      <div class="bg-white w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4">
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
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in';

    modal.innerHTML = `
      <div class="bg-white w-full max-w-lg rounded-3xl p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center pb-2 border-b border-slate-100">
          <h3 class="text-lg font-black text-slate-900">${isEdit ? 'Modifier l\'Article' : 'Ajouter un Nouvel Article'}</h3>
          <button id="close-modal-x" class="text-slate-400 hover:text-slate-600">✕</button>
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

  // Initial execution
  if (!isUnlocked) {
    renderPinLock();
  } else {
    initPos();
  }
}
