import { supabase } from './supabase.js';

export function renderMenuView(container, store, categories, items) {
  let cart = JSON.parse(localStorage.getItem(`allonssy_cart_${store.id}`) || '[]');
  let activeCategory = categories[0]?.id || null;
  let customizerItem = null;
  let selectedSize = null;
  let selectedSauce = null;
  let selectedExtras = [];
  let itemNote = '';
  let itemQty = 1;
  let isCartOpen = false;
  let activeOrder = null;
  let orderSubscription = null;

  function saveCart() {
    localStorage.setItem(`allonssy_cart_${store.id}`, JSON.stringify(cart));
    renderCartBar();
    if (isCartOpen) renderCartDrawer();
  }

  function getCartTotal() {
    return cart.reduce((sum, line) => sum + (line.unit_price * line.quantity), 0);
  }

  function getCartItemCount() {
    return cart.reduce((sum, line) => sum + line.quantity, 0);
  }

  function openCustomizer(item) {
    customizerItem = item;
    itemQty = 1;
    itemNote = '';
    selectedExtras = [];

    // Default size
    if (item.sizes && item.sizes.length > 0) {
      selectedSize = item.sizes[0];
    } else {
      selectedSize = { name: 'Standard', price: item.price };
    }

    // Default sauce
    if (item.base_sauces && item.base_sauces.length > 0) {
      selectedSauce = item.base_sauces[0];
    } else {
      selectedSauce = null;
    }

    renderCustomizerModal();
  }

  function calculateModalPrice() {
    if (!customizerItem) return 0;
    let base = selectedSize ? Number(selectedSize.price) : Number(customizerItem.price);
    let extrasTotal = selectedExtras.reduce((s, ex) => s + Number(ex.price || 0), 0);
    return (base + extrasTotal) * itemQty;
  }

  function addToCart() {
    if (!customizerItem) return;

    let basePrice = selectedSize ? Number(selectedSize.price) : Number(customizerItem.price);
    let extrasTotal = selectedExtras.reduce((s, ex) => s + Number(ex.price || 0), 0);
    let unitPrice = basePrice + extrasTotal;

    const cartLine = {
      id: Math.random().toString(36).substring(2, 9),
      item_id: customizerItem.id,
      name: customizerItem.name,
      selected_size: selectedSize ? selectedSize.name : null,
      selected_sauce: selectedSauce,
      selected_extras: [...selectedExtras],
      unit_price: unitPrice,
      quantity: itemQty,
      notes: itemNote.trim() || null
    };

    cart.push(cartLine);
    saveCart();
    closeCustomizer();
  }

  function closeCustomizer() {
    customizerItem = null;
    const modal = document.getElementById('customizer-modal');
    if (modal) modal.remove();
  }

  function renderCustomizerModal() {
    let existing = document.getElementById('customizer-modal');
    if (existing) existing.remove();

    if (!customizerItem) return;

    const modal = document.createElement('div');
    modal.id = 'customizer-modal';
    modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-fade-in';

    const currentPrice = calculateModalPrice();

    modal.innerHTML = `
      <div class="bg-white w-full max-w-lg rounded-t-3xl sm:rounded-3xl max-h-[92vh] flex flex-col overflow-hidden shadow-2xl safe-bottom">
        <div class="w-10 h-1 bg-slate-300 rounded-full mx-auto mt-2.5 mb-1 sm:hidden shrink-0"></div>
        <!-- Header -->
        <div class="p-4 sm:p-5 border-b border-slate-100 flex items-start justify-between bg-slate-50/70 shrink-0">
          <div class="pr-3">
            <h3 class="text-lg sm:text-xl font-black text-slate-900 leading-tight">${customizerItem.name}</h3>
            ${customizerItem.description ? `<p class="text-xs text-slate-500 mt-1 line-clamp-2 leading-relaxed">${customizerItem.description}</p>` : ''}
          </div>
          <button id="close-modal-btn" class="p-2 text-slate-400 hover:text-slate-700 bg-white rounded-full shadow-sm border border-slate-200 shrink-0">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>

        <!-- Options Body -->
        <div class="p-5 overflow-y-auto space-y-6 flex-1 text-sm">
          <!-- Size Selector -->
          ${customizerItem.sizes && customizerItem.sizes.length > 0 ? `
            <div>
              <label class="block font-bold text-slate-900 mb-2">Choisir la taille <span class="text-xs font-normal text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full ml-1">Obligatoire</span></label>
              <div class="grid grid-cols-3 gap-2.5">
                ${customizerItem.sizes.map((s, idx) => `
                  <button type="button" data-size-idx="${idx}" class="size-btn p-3 rounded-xl border text-left transition-all ${selectedSize?.name === s.name ? 'border-orange-500 bg-orange-50/60 ring-2 ring-orange-500/20' : 'border-slate-200 hover:border-slate-300'}">
                    <div class="font-bold text-slate-900">${s.name}</div>
                    <div class="text-xs text-slate-600 font-semibold mt-1">${Number(s.price).toFixed(2)} €</div>
                  </button>
                `).join('')}
              </div>
            </div>
          ` : ''}

          <!-- Base Sauce Selector -->
          ${customizerItem.base_sauces && customizerItem.base_sauces.length > 0 ? `
            <div>
              <label class="block font-bold text-slate-900 mb-2">Sauce de base</label>
              <div class="grid grid-cols-2 gap-2.5">
                ${customizerItem.base_sauces.map((sauce) => `
                  <button type="button" data-sauce="${sauce}" class="sauce-btn p-3 rounded-xl border text-center font-medium transition-all ${selectedSauce === sauce ? 'border-orange-500 bg-orange-50/60 text-orange-900 font-bold ring-2 ring-orange-500/20' : 'border-slate-200 text-slate-700 hover:border-slate-300'}">
                    ${sauce}
                  </button>
                `).join('')}
              </div>
            </div>
          ` : ''}

          <!-- Extras Checkboxes -->
          ${customizerItem.extras && customizerItem.extras.length > 0 ? `
            <div>
              <label class="block font-bold text-slate-900 mb-2">Suppléments (Optionnels)</label>
              <div class="space-y-2">
                ${customizerItem.extras.map((ex, idx) => {
                  const isChecked = selectedExtras.some(e => e.name === ex.name);
                  return `
                    <label class="flex items-center justify-between p-3 rounded-xl border ${isChecked ? 'border-orange-500 bg-orange-50/40' : 'border-slate-200 hover:border-slate-300'} cursor-pointer">
                      <div class="flex items-center space-x-3">
                        <input type="checkbox" data-extra-idx="${idx}" class="extra-cb w-4 h-4 text-orange-600 rounded border-slate-300 focus:ring-orange-500" ${isChecked ? 'checked' : ''}>
                        <span class="font-medium text-slate-800">${ex.name}</span>
                      </div>
                      <span class="font-semibold text-slate-700">+${Number(ex.price).toFixed(2)} €</span>
                    </label>
                  `;
                }).join('')}
              </div>
            </div>
          ` : ''}

          <!-- Special Note -->
          <div>
            <label class="block font-bold text-slate-900 mb-2">Instructions spéciales</label>
            <input type="text" id="item-note-input" placeholder="Ex: Sans oignons, bien cuit..." value="${itemNote}" class="w-full px-4 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 focus:border-orange-500 text-sm">
          </div>
        </div>

        <!-- Footer / Add to Cart -->
        <div class="p-4 border-t border-slate-100 bg-slate-50 flex items-center justify-between gap-4">
          <div class="flex items-center border border-slate-200 rounded-xl bg-white shadow-sm overflow-hidden">
            <button id="qty-minus" class="px-3 py-2 text-slate-600 hover:bg-slate-100 font-bold text-base">-</button>
            <span id="qty-display" class="px-3 font-bold text-slate-800">${itemQty}</span>
            <button id="qty-plus" class="px-3 py-2 text-slate-600 hover:bg-slate-100 font-bold text-base">+</button>
          </div>

          <button id="add-to-cart-btn" class="flex-1 bg-orange-600 hover:bg-orange-700 text-white font-bold py-3.5 px-6 rounded-xl shadow-lg shadow-orange-600/25 flex items-center justify-between transition-transform active:scale-[0.98]">
            <span>Ajouter au panier</span>
            <span id="modal-price-display">${currentPrice.toFixed(2)} €</span>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    // Event bindings
    modal.querySelector('#close-modal-btn').addEventListener('click', closeCustomizer);
    modal.addEventListener('click', (e) => {
      if (e.target === modal) closeCustomizer();
    });

    // Size selection
    modal.querySelectorAll('.size-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-size-idx'));
        selectedSize = customizerItem.sizes[idx];
        renderCustomizerModal();
      });
    });

    // Sauce selection
    modal.querySelectorAll('.sauce-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        selectedSauce = btn.getAttribute('data-sauce');
        renderCustomizerModal();
      });
    });

    // Extras selection
    modal.querySelectorAll('.extra-cb').forEach(cb => {
      cb.addEventListener('change', () => {
        const idx = Number(cb.getAttribute('data-extra-idx'));
        const extra = customizerItem.extras[idx];
        if (cb.checked) {
          selectedExtras.push(extra);
        } else {
          selectedExtras = selectedExtras.filter(e => e.name !== extra.name);
        }
        renderCustomizerModal();
      });
    });

    // Notes
    modal.querySelector('#item-note-input').addEventListener('input', (e) => {
      itemNote = e.target.value;
    });

    // Qty
    modal.querySelector('#qty-minus').addEventListener('click', () => {
      if (itemQty > 1) {
        itemQty--;
        modal.querySelector('#qty-display').innerText = itemQty;
        modal.querySelector('#modal-price-display').innerText = `${calculateModalPrice().toFixed(2)} €`;
      }
    });

    modal.querySelector('#qty-plus').addEventListener('click', () => {
      itemQty++;
      modal.querySelector('#qty-display').innerText = itemQty;
      modal.querySelector('#modal-price-display').innerText = `${calculateModalPrice().toFixed(2)} €`;
    });

    // Confirm Add
    modal.querySelector('#add-to-cart-btn').addEventListener('click', addToCart);
  }

  function renderCartBar() {
    let bar = document.getElementById('floating-cart-bar');
    const total = getCartTotal();
    const count = getCartItemCount();

    if (count === 0 || activeOrder) {
      if (bar) bar.remove();
      return;
    }

    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'floating-cart-bar';
      bar.className = 'fixed bottom-3 sm:bottom-4 left-3 right-3 sm:left-4 sm:right-4 z-40 max-w-lg mx-auto safe-bottom';
      document.body.appendChild(bar);
    }

    bar.innerHTML = `
      <button id="open-cart-drawer-btn" class="w-full bg-slate-900 hover:bg-black text-white p-4 rounded-2xl shadow-xl flex items-center justify-between transition-transform active:scale-[0.99] border border-slate-800">
        <div class="flex items-center space-x-3">
          <span class="w-8 h-8 rounded-full bg-orange-600 font-bold flex items-center justify-center text-xs">${count}</span>
          <span class="font-bold text-sm tracking-wide">Voir mon panier</span>
        </div>
        <div class="font-extrabold text-base text-orange-400">${total.toFixed(2)} €</div>
      </button>
    `;

    bar.querySelector('#open-cart-drawer-btn').addEventListener('click', () => {
      isCartOpen = true;
      renderCartDrawer();
    });
  }

  function renderCartDrawer() {
    let drawer = document.getElementById('cart-drawer');
    if (drawer) drawer.remove();

    if (!isCartOpen) return;

    drawer = document.createElement('div');
    drawer.id = 'cart-drawer';
    drawer.className = 'fixed inset-0 z-50 flex justify-end bg-black/60 backdrop-blur-sm animate-fade-in';

    const total = getCartTotal();

    drawer.innerHTML = `
      <div class="bg-white w-full max-w-md h-full flex flex-col shadow-2xl">
        <!-- Header -->
        <div class="p-5 border-b border-slate-100 flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <h2 class="text-lg font-bold text-slate-900">Mon Panier</h2>
            <span class="text-xs bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-bold">${cart.length}</span>
          </div>
          <button id="close-cart-btn" class="p-2 text-slate-400 hover:text-slate-700 rounded-full hover:bg-slate-100">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>

        <!-- Items List -->
        <div class="p-5 overflow-y-auto flex-1 space-y-4">
          ${cart.map((line, idx) => `
            <div class="p-3.5 rounded-xl border border-slate-100 bg-slate-50/50 flex flex-col space-y-2">
              <div class="flex justify-between items-start">
                <div>
                  <h4 class="font-bold text-slate-900">${line.name}</h4>
                  <div class="text-xs text-slate-500 space-y-0.5 mt-0.5">
                    ${line.selected_size ? `<div>Taille: <span class="font-semibold text-slate-700">${line.selected_size}</span></div>` : ''}
                    ${line.selected_sauce ? `<div>Sauce: <span class="font-semibold text-slate-700">${line.selected_sauce}</span></div>` : ''}
                    ${line.selected_extras && line.selected_extras.length > 0 ? `<div>Suppléments: ${line.selected_extras.map(e => e.name).join(', ')}</div>` : ''}
                    ${line.notes ? `<div class="italic text-orange-600 font-medium">"${line.notes}"</div>` : ''}
                  </div>
                </div>
                <div class="font-bold text-slate-900">${(line.unit_price * line.quantity).toFixed(2)} €</div>
              </div>

              <!-- Line quantity controls -->
              <div class="flex items-center justify-between pt-1 border-t border-slate-100">
                <button data-remove-idx="${idx}" class="remove-line-btn text-xs text-red-500 hover:text-red-700 font-semibold">Supprimer</button>
                <div class="flex items-center space-x-2 bg-white rounded-lg border border-slate-200 px-2 py-0.5 text-xs">
                  <button data-minus-idx="${idx}" class="minus-line-btn font-bold px-1 text-slate-600">-</button>
                  <span class="font-bold text-slate-800">${line.quantity}</span>
                  <button data-plus-idx="${idx}" class="plus-line-btn font-bold px-1 text-slate-600">+</button>
                </div>
              </div>
            </div>
          `).join('')}

          <!-- Checkout Form -->
          <div class="mt-6 pt-5 border-t border-slate-200 space-y-4">
            <h3 class="font-bold text-slate-900">Coordonnées pour le retrait</h3>
            <div>
              <label class="block text-xs font-semibold text-slate-600 mb-1">Votre Nom & Prénom *</label>
              <input type="text" id="cust-name-input" placeholder="Ex: Karim Dupont" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm">
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-600 mb-1">Téléphone (pour vous avertir) *</label>
              <input type="tel" id="cust-phone-input" placeholder="06 12 34 56 78" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm">
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-600 mb-1">Heure de retrait souhaitée</label>
              <select id="cust-time-select" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-orange-500 text-sm bg-white">
                <option value="Dès que possible (~20 min)">Dès que possible (~20 min)</option>
                <option value="Dans 30 minutes">Dans 30 minutes</option>
                <option value="Dans 45 minutes">Dans 45 minutes</option>
                <option value="Dans 1 heure">Dans 1 heure</option>
              </select>
            </div>

            <!-- Payment mode note -->
            <div class="p-3 bg-orange-50/70 border border-orange-100 rounded-xl text-xs text-orange-900 flex items-start space-x-2">
              <svg class="w-4 h-4 text-orange-600 mt-0.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
              <span><strong>Paiement au comptoir</strong> : vous réglez directement en espèces ou par carte bancaire lors du retrait de votre commande.</span>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-slate-100 bg-slate-50">
          <div class="flex justify-between items-center mb-3">
            <span class="text-sm font-semibold text-slate-600">Total à régler au retrait :</span>
            <span class="text-xl font-extrabold text-slate-900">${total.toFixed(2)} €</span>
          </div>

          <button id="submit-order-btn" class="w-full bg-orange-600 hover:bg-orange-700 text-white font-bold py-3.5 px-4 rounded-xl shadow-lg shadow-orange-600/30 flex items-center justify-center space-x-2 transition-transform active:scale-[0.99]">
            <span>Confirmer la commande</span>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/></svg>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(drawer);

    // Event bindings for drawer
    drawer.querySelector('#close-cart-btn').addEventListener('click', () => {
      isCartOpen = false;
      renderCartDrawer();
    });

    drawer.addEventListener('click', (e) => {
      if (e.target === drawer) {
        isCartOpen = false;
        renderCartDrawer();
      }
    });

    drawer.querySelectorAll('.remove-line-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-remove-idx'));
        cart.splice(idx, 1);
        saveCart();
      });
    });

    drawer.querySelectorAll('.minus-line-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-minus-idx'));
        if (cart[idx].quantity > 1) {
          cart[idx].quantity--;
        } else {
          cart.splice(idx, 1);
        }
        saveCart();
      });
    });

    drawer.querySelectorAll('.plus-line-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-plus-idx'));
        cart[idx].quantity++;
        saveCart();
      });
    });

    drawer.querySelector('#submit-order-btn').addEventListener('click', submitOrder);
  }

  async function submitOrder() {
    const nameInput = document.getElementById('cust-name-input');
    const phoneInput = document.getElementById('cust-phone-input');
    const timeSelect = document.getElementById('cust-time-select');

    const name = nameInput?.value.trim();
    const phone = phoneInput?.value.trim();
    const pickupTime = timeSelect?.value || 'Dès que possible (~20 min)';

    if (!name || name.length < 2) {
      alert('Veuillez renseigner votre nom pour le retrait.');
      nameInput?.focus();
      return;
    }

    if (!phone || phone.length < 8) {
      alert('Veuillez renseigner un numéro de téléphone valide.');
      phoneInput?.focus();
      return;
    }

    const submitBtn = document.getElementById('submit-order-btn');
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.innerText = 'Envoi de votre commande...';
    }

    try {
      const total = getCartTotal();

      // 1. Insert order
      const { data: orderData, error: orderError } = await supabase
        .from('restaurant_orders')
        .insert({
          store_id: store.id,
          customer_name: name,
          customer_phone: phone,
          order_type: 'takeaway',
          pickup_time: pickupTime,
          status: 'received',
          payment_method: 'at_pickup',
          payment_status: 'pending',
          total_price: total
        })
        .select()
        .single();

      if (orderError) throw orderError;

      // 2. Insert order items
      const orderItemsToInsert = cart.map(line => ({
        order_id: orderData.id,
        item_name: line.name,
        selected_size: line.selected_size,
        selected_sauce: line.selected_sauce,
        selected_extras: line.selected_extras,
        quantity: line.quantity,
        unit_price: line.unit_price,
        total_price: line.unit_price * line.quantity,
        notes: line.notes
      }));

      const { error: itemsError } = await supabase
        .from('restaurant_order_items')
        .insert(orderItemsToInsert);

      if (itemsError) throw itemsError;

      // Success: clear cart & show confirmation
      cart = [];
      saveCart();
      isCartOpen = false;
      renderCartDrawer();

      activeOrder = orderData;
      listenToOrder(orderData.id);
      renderOrderTrackingModal();

    } catch (err) {
      console.error('Order placement failed:', err);
      alert("Une erreur est survenue lors de l'enregistrement de votre commande. Veuillez réessayer.");
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.innerText = 'Confirmer la commande';
      }
    }
  }

  function listenToOrder(orderId) {
    if (orderSubscription) {
      supabase.removeChannel(orderSubscription);
    }

    orderSubscription = supabase
      .channel(`order_tracking_${orderId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'restaurant_orders',
        filter: `id=eq.${orderId}`
      }, (payload) => {
        activeOrder = payload.new;
        renderOrderTrackingModal();
      })
      .subscribe();
  }

  function renderOrderTrackingModal() {
    let existing = document.getElementById('order-tracking-modal');
    if (existing) existing.remove();

    if (!activeOrder) return;

    const modal = document.createElement('div');
    modal.id = 'order-tracking-modal';
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-fade-in';

    const statusMap = {
      received: {
        label: 'Reçue en cuisine',
        desc: 'Le restaurant a bien reçu votre commande et va la préparer.',
        badge: 'bg-amber-100 text-amber-900 border-amber-200',
        dot: 'bg-amber-500 animate-pulse'
      },
      preparing: {
        label: 'En préparation au four',
        desc: 'Votre pizza est en cours de cuisson !',
        badge: 'bg-blue-100 text-blue-900 border-blue-200',
        dot: 'bg-blue-500 animate-pulse'
      },
      ready: {
        label: 'Prête ! Vous pouvez la retirer',
        desc: 'Votre commande est prête et vous attend au comptoir.',
        badge: 'bg-green-100 text-green-900 border-green-200',
        dot: 'bg-green-500'
      },
      completed: {
        label: 'Terminée & Récupérée',
        desc: 'Merci pour votre confiance et bon appétit !',
        badge: 'bg-slate-100 text-slate-800 border-slate-200',
        dot: 'bg-slate-500'
      }
    };

    const st = statusMap[activeOrder.status] || statusMap.received;

    modal.innerHTML = `
      <div class="bg-white w-full max-w-md rounded-3xl overflow-hidden shadow-2xl p-6 text-center space-y-6">
        <div class="w-16 h-16 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center mx-auto shadow-inner">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
        </div>

        <div>
          <span class="text-xs uppercase tracking-wider font-extrabold text-slate-400">Numéro de Commande</span>
          <div class="text-4xl font-black text-slate-900 tracking-tight mt-1">#${activeOrder.order_number}</div>
        </div>

        <!-- Status Card -->
        <div class="p-4 rounded-2xl border ${st.badge} text-left">
          <div class="flex items-center space-x-2">
            <span class="w-3 h-3 rounded-full ${st.dot}"></span>
            <span class="font-extrabold text-sm uppercase tracking-wide">${st.label}</span>
          </div>
          <p class="text-xs mt-1.5 opacity-90">${st.desc}</p>
        </div>

        <!-- Details -->
        <div class="bg-slate-50 rounded-2xl p-4 text-xs text-slate-600 space-y-2 text-left border border-slate-100">
          <div class="flex justify-between">
            <span class="text-slate-500">Client :</span>
            <span class="font-bold text-slate-900">${activeOrder.customer_name}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">Téléphone :</span>
            <span class="font-bold text-slate-900">${activeOrder.customer_phone}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">Heure souhaitée :</span>
            <span class="font-bold text-orange-600">${activeOrder.pickup_time || 'Dès que possible'}</span>
          </div>
          <div class="flex justify-between pt-2 border-t border-slate-200">
            <span class="text-slate-500 font-bold">Total à payer au retrait :</span>
            <span class="font-extrabold text-slate-900 text-sm">${Number(activeOrder.total_price).toFixed(2)} €</span>
          </div>
        </div>

        <button id="close-tracking-btn" class="w-full bg-slate-900 hover:bg-black text-white font-bold py-3.5 rounded-xl shadow-md transition-colors">
          Nouvelle commande
        </button>
      </div>
    `;

    document.body.appendChild(modal);

    modal.querySelector('#close-tracking-btn').addEventListener('click', () => {
      activeOrder = null;
      if (orderSubscription) supabase.removeChannel(orderSubscription);
      modal.remove();
    });
  }

  // Initial Main Render
  container.innerHTML = `
    <!-- Restaurant Header -->
    <header class="bg-white/95 backdrop-blur-md border-b border-slate-100 shadow-sm sticky top-0 z-30">
      <div class="max-w-5xl mx-auto px-4 py-3 sm:py-4">
        <!-- Top Row: Brand & Status & Quick POS access -->
        <div class="flex items-center justify-between gap-2">
          <div class="flex items-center space-x-2 min-w-0">
            <h1 class="text-xl sm:text-2xl font-black text-slate-900 tracking-tight truncate">${store.name}</h1>
            <span class="bg-emerald-100 text-emerald-800 text-[10px] font-extrabold px-2 py-0.5 rounded-full uppercase tracking-wider shrink-0">Ouvert</span>
          </div>

          <a href="#pos" class="text-xs font-bold bg-slate-100 hover:bg-slate-200 text-slate-700 px-3 py-1.5 rounded-xl flex items-center space-x-1.5 transition-colors shrink-0 border border-slate-200">
            <svg class="w-3.5 h-3.5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
            <span class="hidden sm:inline">Espace</span><span>Caisse / POS</span>
          </a>
        </div>

        <!-- Info Row: Address & Phone -->
        <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500 mt-1.5">
          <a href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(store.address + ' ' + store.city)}" target="_blank" rel="noopener noreferrer" class="hover:text-slate-800 flex items-center space-x-1 text-slate-600 truncate">
            <svg class="w-3.5 h-3.5 text-slate-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/></svg>
            <span class="truncate">${store.address}, ${store.city}</span>
          </a>
          <span class="text-slate-300 hidden sm:inline">•</span>
          <a href="tel:${store.phone}" class="text-orange-600 font-bold hover:underline flex items-center space-x-1 shrink-0">
            <svg class="w-3.5 h-3.5 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/></svg>
            <span>${store.phone}</span>
          </a>
        </div>
      </div>

      <!-- Categories Pills Navigation -->
      <div class="max-w-5xl mx-auto px-4 overflow-x-auto hide-scrollbar flex space-x-2 py-2 border-t border-slate-100">
        ${categories.map(c => `
          <button data-cat-id="${c.id}" class="cat-pill-btn whitespace-nowrap px-3.5 py-1.5 sm:px-4 sm:py-2 rounded-xl text-xs font-bold transition-all ${c.id === activeCategory ? 'bg-orange-600 text-white shadow-md shadow-orange-600/20' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}">
            ${c.name}
          </button>
        `).join('')}
      </div>
    </header>

    <!-- Menu Items List -->
    <main class="max-w-5xl mx-auto px-4 py-6 flex-1 w-full space-y-8 pb-28">
      ${categories.map(c => {
        const catItems = items.filter(i => i.category_id === c.id);
        if (catItems.length === 0) return '';
        return `
          <section id="category-section-${c.id}" class="space-y-4">
            <h2 class="text-lg font-black text-slate-900 tracking-tight flex items-center space-x-2">
              <span>${c.name}</span>
              <span class="text-xs font-semibold text-slate-400">(${catItems.length})</span>
            </h2>

            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              ${catItems.map(item => {
                const minPrice = item.sizes && item.sizes.length > 0
                  ? Math.min(...item.sizes.map(s => Number(s.price)))
                  : Number(item.price);
                const hasOptions = (item.sizes && item.sizes.length > 0) || (item.base_sauces && item.base_sauces.length > 0) || (item.extras && item.extras.length > 0);

                return `
                  <div class="bg-white rounded-2xl border border-slate-100 p-4 shadow-sm hover:shadow-md transition-all flex flex-col justify-between group">
                    <div>
                      <div class="flex justify-between items-start gap-2">
                        <h3 class="font-bold text-slate-900 text-base group-hover:text-orange-600 transition-colors">${item.name}</h3>
                        <span class="font-extrabold text-slate-900 text-sm whitespace-nowrap bg-orange-50 text-orange-700 px-2.5 py-1 rounded-lg">
                          ${hasOptions ? 'Dès ' : ''}${minPrice.toFixed(2)} €
                        </span>
                      </div>
                      ${item.description ? `<p class="text-xs text-slate-500 mt-2 line-clamp-2 leading-relaxed">${item.description}</p>` : ''}
                    </div>

                    <div class="mt-4 pt-3 border-t border-slate-50 flex items-center justify-between">
                      <span class="text-[11px] text-slate-400 font-medium">
                        ${item.sizes && item.sizes.length > 0 ? `${item.sizes.length} formats` : 'Format unique'}
                      </span>
                      <button data-item-id="${item.id}" class="add-item-btn bg-slate-900 hover:bg-orange-600 text-white font-bold text-xs px-3.5 py-2 rounded-xl transition-all shadow-sm flex items-center space-x-1 active:scale-95">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/></svg>
                        <span>Choisir</span>
                      </button>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          </section>
        `;
      }).join('')}
    </main>
  `;

  // Bind category pills
  container.querySelectorAll('.cat-pill-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const catId = btn.getAttribute('data-cat-id');
      activeCategory = catId;
      container.querySelectorAll('.cat-pill-btn').forEach(b => {
        b.className = `cat-pill-btn whitespace-nowrap px-4 py-2 rounded-xl text-xs font-bold transition-all ${b.getAttribute('data-cat-id') === catId ? 'bg-orange-600 text-white shadow-md shadow-orange-600/20' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`;
      });
      const section = document.getElementById(`category-section-${catId}`);
      if (section) {
        section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // Bind add item buttons
  container.querySelectorAll('.add-item-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const itemId = btn.getAttribute('data-item-id');
      const item = items.find(i => i.id === itemId);
      if (item) openCustomizer(item);
    });
  });

  renderCartBar();
}
